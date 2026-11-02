# frozen_string_literal: true

module ::DiscourseImageAlbum
  class AlbumsController < ::ApplicationController
    requires_plugin ::DiscourseImageAlbum::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_plugin_enabled
    before_action :ensure_user_can_use_albums
    before_action :find_album, only: [:show, :update, :destroy, :download]

    def index
      target_user = current_user
      if current_user.admin? && params[:user_id].present?
        target_user = User.find_by(id: params[:user_id]) || current_user
      end

      albums = ImageAlbum.where(user_id: target_user.id).order(:name)
      render_serialized(albums, ImageAlbumSerializer, root: "albums")
    end

    def show
      render_serialized(@album, ImageAlbumSerializer, root: "album")
    end

    def create
      params.require(:name)

      album = ImageAlbum.new(
        user_id: current_user.id,
        name: params[:name].to_s.strip,
        description: params[:description].to_s.strip.presence,
        parent_id: params[:parent_id].presence
      )

      if album.save
        render_serialized(album, ImageAlbumSerializer, root: "album")
      else
        render_json_error(album.errors.full_messages.join(", "))
      end
    end

    def update
      params.require(:name)

      @album.name = params[:name].to_s.strip
      @album.description = params[:description].to_s.strip.presence
      @album.parent_id = params[:parent_id].presence if params.key?(:parent_id)

      if @album.save
        render_serialized(@album, ImageAlbumSerializer, root: "album")
      else
        render_json_error(@album.errors.full_messages.join(", "))
      end
    end

    def destroy
      @album.destroy
      render json: success_json
    end

    def download
      quota = QuotaCalculator.for_user(current_user)
      unless quota.can_download_zip?
        return render_json_error(I18n.t("discourse_image_album.errors.download_disabled"), status: 403)
      end

      zip_file = ZipExporter.export(@album)
      if zip_file && File.exist?(zip_file.path)
        send_file(
          zip_file.path,
          type: "application/zip",
          disposition: "attachment",
          filename: "#{ActiveStorage::Filename.new(@album.name).sanitized}.zip"
        )
      else
        render_json_error("Failed to generate ZIP archive.")
      end
    end

    def quota
      quota_data = QuotaCalculator.for_user(current_user).to_h
      render json: { quota: quota_data }
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

    def find_album
      scope = ImageAlbum.where(id: params[:id])
      scope = scope.where(user_id: current_user.id) unless current_user.admin?

      @album = scope.first
      if @album.blank?
        render_json_error(I18n.t("discourse_image_album.errors.album_not_found"), status: 404)
      end
    end
  end
end
