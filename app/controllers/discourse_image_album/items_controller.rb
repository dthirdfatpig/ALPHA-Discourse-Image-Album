# frozen_string_literal: true

module ::DiscourseImageAlbum
  class ItemsController < ::ApplicationController
    requires_plugin ::DiscourseImageAlbum::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_plugin_enabled
    before_action :ensure_user_can_use_albums

    def index
      album = find_user_album(params[:album_id])
      return render_json_error(I18n.t("discourse_image_album.errors.album_not_found"), status: 404) unless album

      page = [params[:page].to_i, 1].max
      limit = [params[:limit].to_i, 50].max
      limit = 100 if limit > 100

      offset = (page - 1) * limit
      total_count = album.items.count

      items = album.items
                   .includes(upload: :optimized_images)
                   .order(id: :desc)
                   .offset(offset)
                   .limit(limit)

      serialized = ActiveModel::ArraySerializer.new(
        items,
        each_serializer: ImageAlbumItemSerializer
      ).as_json

      render json: {
        items: serialized,
        meta: {
          total_count: total_count,
          page: page,
          limit: limit,
          total_pages: (total_count.to_f / limit).ceil
        }
      }
    end

    def create
      album = find_user_album(params[:album_id])
      return render_json_error(I18n.t("discourse_image_album.errors.album_not_found"), status: 404) unless album

      upload = nil
      if params[:upload_id].present?
        upload = Upload.find_by(id: params[:upload_id])
      end

      item = ImageAlbumItem.new(
        album_id: album.id,
        user_id: current_user.id,
        upload_id: upload&.id,
        image_url: params[:image_url].presence,
        title: params[:title].to_s.strip.presence,
        source_post_id: params[:source_post_id].presence,
        source_topic_id: params[:source_topic_id].presence
      )

      if item.save
        render_serialized(item, ImageAlbumItemSerializer, root: "item")
      else
        render_json_error(item.errors.full_messages.join(", "))
      end
    end

    def save_from_post
      album_id = params[:album_id]
      album = find_user_album(album_id)
      return render_json_error(I18n.t("discourse_image_album.errors.album_not_found"), status: 404) unless album

      image_url = params[:image_url].to_s.strip
      thumbnail_url = params[:thumbnail_url].to_s.strip.presence
      post_id = params[:post_id].presence
      post = Post.find_by(id: post_id) if post_id

      upload = nil
      if image_url.present?
        upload = Upload.get_from_url(image_url)
      end

      if upload.blank? && thumbnail_url.present?
        upload = Upload.get_from_url(thumbnail_url)
      end

      if upload.blank? && post.present?
        # Try matching upload from post
        upload = post.uploads.find do |u|
          (image_url.present? && (image_url.include?(u.sha1) || image_url.include?(u.url))) ||
          (thumbnail_url.present? && (thumbnail_url.include?(u.sha1) || thumbnail_url.include?(u.url)))
        end
      end

      # Check if external hotlinks allowed when upload is nil
      if upload.blank? && !SiteSetting.image_album_allow_external_hotlinks
        return render_json_error("Saving external hotlinked images is disabled.", status: 400)
      end

      # Avoid duplicate save of identical image in the same album
      existing = if upload.present?
        album.items.find_by(upload_id: upload.id)
      else
        album.items.find_by(image_url: image_url)
      end

      if existing
        return render json: {
          success: true,
          already_saved: true,
          album_name: album.name,
          item: ImageAlbumItemSerializer.new(existing, root: false).as_json
        }
      end

      item = ImageAlbumItem.new(
        album_id: album.id,
        user_id: current_user.id,
        upload_id: upload&.id,
        image_url: image_url.presence || upload&.url,
        thumbnail_url: thumbnail_url,
        title: params[:title].presence || post&.topic&.title,
        source_post_id: post&.id,
        source_topic_id: post&.topic_id
      )

      if item.save
        render json: {
          success: true,
          already_saved: false,
          item: ImageAlbumItemSerializer.new(item, root: false).as_json
        }
      else
        render_json_error(item.errors.full_messages.join(", "))
      end
    end

    def check
      image_url = params[:image_url].to_s.strip
      thumbnail_url = params[:thumbnail_url].to_s.strip.presence
      post_id = params[:post_id].presence
      post = Post.find_by(id: post_id) if post_id

      upload = nil
      upload = Upload.get_from_url(image_url) if image_url.present?
      upload ||= Upload.get_from_url(thumbnail_url) if thumbnail_url.present?

      if upload.blank? && post.present?
        upload = post.uploads.find do |u|
          (image_url.present? && (image_url.include?(u.sha1) || image_url.include?(u.url))) ||
          (thumbnail_url.present? && (thumbnail_url.include?(u.sha1) || thumbnail_url.include?(u.url)))
        end
      end

      scope = ImageAlbumItem.joins(:album).where("image_album_items.user_id = ?", current_user.id)
      if upload.present?
        scope = scope.where("image_album_items.upload_id = ? OR image_album_items.image_url = ?", upload.id, image_url)
      elsif image_url.present?
        scope = scope.where("image_album_items.image_url = ?", image_url)
      else
        return render json: { already_saved: false, existing_albums: [] }
      end

      existing_albums = scope.distinct.pluck("image_albums.id", "image_albums.name").map do |id, name|
        { id: id, name: name }
      end

      render json: {
        already_saved: existing_albums.any?,
        existing_albums: existing_albums
      }
    end

    def move
      target_album = find_user_album(params[:target_album_id])
      return render_json_error(I18n.t("discourse_image_album.errors.target_album_invalid"), status: 404) unless target_album

      item_ids = Array(params[:item_ids]).map(&:to_i).uniq
      max_bulk = SiteSetting.image_album_max_bulk_selection.to_i
      if item_ids.length > max_bulk
        return render_json_error(I18n.t("discourse_image_album.errors.bulk_limit_exceeded", limit: max_bulk), status: 400)
      end

      scope = ImageAlbumItem.where(id: item_ids)
      scope = scope.where(user_id: current_user.id) unless current_user.admin?

      items = scope.to_a
      return render_json_error(I18n.t("discourse_image_album.errors.item_not_found"), status: 404) if items.empty?

      # Check capacity of target album
      quota = QuotaCalculator.for_user(current_user)
      unless quota.album_has_capacity?(target_album, items.length)
        return render_json_error(I18n.t("discourse_image_album.errors.album_quota_exceeded", limit: quota.max_images_per_album))
      end

      old_album_ids = items.map(&:album_id).uniq

      ActiveRecord::Base.transaction do
        items.each do |item|
          item.update!(album_id: target_album.id)
        end
        # Refresh counters
        ImageAlbum.reset_counters(target_album.id, :items)
        old_album_ids.each { |aid| ImageAlbum.reset_counters(aid, :items) }
      end

      render json: { success: true, moved_count: items.length }
    end

    def destroy_multiple
      item_ids = Array(params[:item_ids]).map(&:to_i).uniq
      scope = ImageAlbumItem.where(id: item_ids)
      scope = scope.where(user_id: current_user.id) unless current_user.admin?

      items = scope.to_a
      return render_json_error(I18n.t("discourse_image_album.errors.item_not_found"), status: 404) if items.empty?

      album_ids = items.map(&:album_id).uniq

      ActiveRecord::Base.transaction do
        items.each(&:destroy)
        album_ids.each { |aid| ImageAlbum.reset_counters(aid, :items) }
      end

      render json: { success: true, deleted_count: items.length }
    end

    def destroy
      scope = ImageAlbumItem.where(id: params[:id])
      scope = scope.where(user_id: current_user.id) unless current_user.admin?

      item = scope.first
      return render_json_error(I18n.t("discourse_image_album.errors.item_not_found"), status: 404) unless item

      album_id = item.album_id
      item.destroy
      ImageAlbum.reset_counters(album_id, :items)

      render json: success_json
    end

    private

    def ensure_plugin_enabled
      raise Discourse::NotFound unless SiteSetting.image_album_enabled
    end

    def ensure_user_can_use_albums
      quota = QuotaCalculator.for_user(current_user)
      unless quota.can_use_albums?
        render_json_error(
          I18n.t("discourse_image_album.errors.min_trust_level_required", level: SiteSetting.image_album_min_trust_level_to_use),
          status: 403
        )
      end
    end

    def find_user_album(album_id)
      scope = ImageAlbum.where(id: album_id)
      scope = scope.where(user_id: current_user.id) unless current_user.admin?
      scope.first
    end
  end
end
