# frozen_string_literal: true

module ::DiscourseImageAlbum
  class AdminController < ::ApplicationController
    requires_plugin ::DiscourseImageAlbum::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_admin

    def index
      overrides = ImageAlbumUserOverride.includes(:user).all
      data = overrides.map do |ov|
        {
          user_id: ov.user_id,
          username: ov.user&.username,
          avatar_template: ov.user&.avatar_template,
          max_images: ov.max_images,
          max_disk_mb: ov.max_disk_mb,
          can_download_zip: ov.can_download_zip,
          updated_at: ov.updated_at
        }
      end

      render json: { overrides: data }
    end

    def save_override
      user = if params[:user_id].present?
        User.find_by(id: params[:user_id])
      elsif params[:username].present?
        User.find_by_username(params[:username])
      end

      return render_json_error("User not found", status: 404) unless user

      override = ImageAlbumUserOverride.find_or_initialize_by(user_id: user.id)
      override.max_images = params[:max_images].presence&.to_i
      override.max_disk_mb = params[:max_disk_mb].presence&.to_i
      override.can_download_zip = params[:can_download_zip] if params.key?(:can_download_zip)

      if override.save
        render json: {
          success: true,
          override: {
            user_id: user.id,
            username: user.username,
            max_images: override.max_images,
            max_disk_mb: override.max_disk_mb,
            can_download_zip: override.can_download_zip
          }
        }
      else
        render_json_error(override.errors.full_messages.join(", "))
      end
    end

    def delete_override
      override = ImageAlbumUserOverride.find_by(user_id: params[:user_id])
      override&.destroy
      render json: success_json
    end
  end
end
