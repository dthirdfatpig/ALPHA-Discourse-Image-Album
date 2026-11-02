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
      if upload.present?
        upload.url
      else
        image_url
      end
    end

    def thumb_url
      if thumbnail_url.present?
        thumbnail_url
      elsif upload.present?
        upload.thumbnail(200, 200)&.url.presence || upload.url
      else
        image_url
      end
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
      self.thumbnail_url ||= upload.thumbnail(200, 200)&.url if thumbnail_url.blank?
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
