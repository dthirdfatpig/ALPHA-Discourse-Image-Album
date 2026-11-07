# frozen_string_literal: true

module ::DiscourseImageAlbum
  class ImageAlbumItem < ::ActiveRecord::Base
    self.table_name = "image_album_items"

    belongs_to :album, class_name: "::DiscourseImageAlbum::ImageAlbum", counter_cache: :images_count
    belongs_to :user
    belongs_to :upload, optional: true
    belongs_to :source_post, class_name: "::Post", optional: true
    belongs_to :source_topic, class_name: "::Topic", optional: true

    validates :album_id, presence: true
    validates :user_id, presence: true
    validate :validate_image_source
    validate :validate_album_capacity, on: :create
    validate :validate_user_quota, on: :create

    before_validation :populate_metadata_from_upload, on: :create

    def url
      @_cooked_url ||= begin
        raw_url = if upload.present?
          upload.url
        else
          image_url
        end
        self.class.cook_url(raw_url, upload: upload)
      end
    end

    def thumb_url
      @_cooked_thumb_url ||= begin
        if upload.present?
          best_opt = find_best_optimized_image
          raw_thumb = best_opt&.url.presence || thumbnail_url.presence || upload.url
          self.class.cook_url(raw_thumb, upload: upload)
        elsif thumbnail_url.present?
          self.class.cook_url(thumbnail_url)
        else
          self.class.cook_url(image_url)
        end
      end
    end

    def find_best_optimized_image
      return nil unless upload.present?
      return @_best_optimized if defined?(@_best_optimized)

      # 1. Look for existing optimized versions on the upload
      opts = upload.optimized_images.to_a
      if opts.any?
        # Target thumbnail width between 180px and 700px
        suitable = opts.select { |oi| oi.width.to_i >= 180 }
        @_best_optimized = suitable.min_by { |oi| oi.width.to_i } || opts.max_by { |oi| oi.width.to_i }
        return @_best_optimized
      end

      # 2. Try creating or fetching an optimized thumbnail via Discourse
      @_best_optimized = begin
        if upload.respond_to?(:get_optimized_image)
          upload.get_optimized_image(400, 400)
        elsif upload.respond_to?(:thumbnail)
          upload.thumbnail(400, 400) || upload.thumbnail
        end
      rescue => e
        nil
      end
      @_best_optimized
    end

    def self.cook_url(raw_url, upload: nil)
      return "" if raw_url.blank?

      url = raw_url.to_s.strip

      # 1. Use Discourse UrlHelper.cook_url
      if defined?(::UrlHelper) && ::UrlHelper.respond_to?(:cook_url)
        begin
          cooked = ::UrlHelper.cook_url(url, secure: upload&.secure?, local: true)
          url = cooked if cooked.present?
        rescue => e
          # continue
        end
      end

      # 2. Use Discourse.store.cdn_url
      if defined?(::Discourse) && ::Discourse.respond_to?(:store) && ::Discourse.store.respond_to?(:cdn_url)
        begin
          cdn = ::Discourse.store.cdn_url(url)
          url = cdn if cdn.present?
        rescue => e
          # continue
        end
      end

      # 3. Direct S3 CDN replacement if configured and URL still references raw endpoint or bucket
      s3_cdn = SiteSetting.try(:s3_cdn_url).presence || GlobalSetting.try(:s3_cdn_url).presence
      if s3_cdn.present?
        clean_cdn = s3_cdn.sub(%r{/\z}, "")

        endpoint = SiteSetting.try(:s3_endpoint).presence || GlobalSetting.try(:s3_endpoint).presence
        if endpoint.present?
          endpoint_host = (URI.parse(endpoint).host rescue nil)
          if endpoint_host.present? && url.include?(endpoint_host)
            url = url.sub(%r{(https?:)?//([^/]+)/}, "#{clean_cdn}/")
          end
        end

        bucket = SiteSetting.try(:s3_bucket).presence || GlobalSetting.try(:s3_bucket).presence
        if bucket.present? && url.include?("#{bucket}.")
          url = url.sub(%r{(https?:)?//#{Regexp.escape(bucket)}\.[^/]+/}, "#{clean_cdn}/")
        end
      end

      # 4. If URL still points directly to private R2 storage without a CDN,
      # fallback to upload.short_path so Discourse's controller serves the asset
      if url.include?(".r2.cloudflarestorage.com") && upload.present? && upload.respond_to?(:short_path)
        url = upload.short_path
      end

      # 5. Fix scheme and relative path
      if url.start_with?("//")
        scheme = SiteSetting.try(:force_https) ? "https:" : "http:"
        url = "#{scheme}#{url}"
      elsif url.start_with?("/")
        base = Discourse.try(:base_url) || ""
        url = "#{base}#{url}"
      end

      url
    end

    def markdown_syntax
      title_part = title.presence || original_filename.presence || "image"
      title_escaped = title_part.gsub(/[\[\]]/, "")

      if upload.present?
        short_url = upload.short_url.presence || upload.url
        dim = (width.present? && height.present? && width > 0 && height > 0) ? "|#{width}x#{height}" : ""
        "![#{title_escaped}#{dim}](#{short_url})"
      elsif image_url.present?
        "![#{title_escaped}](#{image_url})"
      else
        ""
      end
    end

    private

    def populate_metadata_from_upload
      return if upload.blank?

      self.original_filename ||= upload.original_filename
      self.filesize = upload.filesize if filesize.blank? || filesize == 0
      self.width ||= upload.width
      self.height ||= upload.height
      self.image_url ||= upload.url

      if thumbnail_url.blank?
        best_opt = find_best_optimized_image
        self.thumbnail_url = best_opt&.url if best_opt.present?
      end
    end

    def validate_image_source
      if upload_id.blank? && image_url.blank?
        errors.add(:base, I18n.t("discourse_image_album.errors.no_valid_images"))
      end
    end

    def validate_album_capacity
      return if album.blank? || user&.admin?

      quota = QuotaCalculator.for_user(user)
      unless quota.album_has_capacity?(album, 1)
        errors.add(:base, I18n.t("discourse_image_album.errors.album_quota_exceeded", limit: quota.max_images_per_album))
      end
    end

    def validate_user_quota
      return if user.blank? || user.admin?

      quota = QuotaCalculator.for_user(user)
      unless quota.can_add_images?(1)
        if quota.max_disk_mb > 0 && quota.current_mb_used >= quota.max_disk_mb
          errors.add(:base, I18n.t("discourse_image_album.errors.disk_quota_exceeded", limit: quota.max_disk_mb))
        else
          errors.add(:base, I18n.t("discourse_image_album.errors.user_quota_exceeded", limit: quota.max_images))
        end
      end
    end
  end
end
