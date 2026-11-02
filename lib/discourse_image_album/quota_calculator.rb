# frozen_string_literal: true

module ::DiscourseImageAlbum
  class QuotaCalculator
    def self.for_user(user)
      new(user)
    end

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def can_use_albums?
      return false unless SiteSetting.image_album_enabled
      return true if user.staff?
      user.trust_level >= SiteSetting.image_album_min_trust_level_to_use
    end

    def override
      return nil unless SiteSetting.image_album_allow_admin_custom_quotas
      @override ||= ImageAlbumUserOverride.find_by(user_id: user.id)
    end

    def max_images
      if override&.max_images.present?
        return override.max_images.to_i
      end

      tl_limit = case user.trust_level
      when 0 then SiteSetting.image_album_max_images_tl0
      when 1 then SiteSetting.image_album_max_images_tl1
      when 2 then SiteSetting.image_album_max_images_tl2
      when 3 then SiteSetting.image_album_max_images_tl3
      else SiteSetting.image_album_max_images_tl4
      end

      global_limit = SiteSetting.image_album_max_total_images_per_user.to_i
      [tl_limit.to_i, global_limit].min
    end

    def max_disk_mb
      if override&.max_disk_mb.present?
        return override.max_disk_mb.to_i
      end

      SiteSetting.image_album_max_disk_quota_mb.to_i
    end

    def max_images_per_album
      SiteSetting.image_album_max_images_per_album.to_i
    end

    def can_download_zip?
      return false unless SiteSetting.image_album_enabled
      return true if user.staff?

      if override && !override.can_download_zip.nil?
        return override.can_download_zip
      end

      SiteSetting.image_album_enable_whole_album_download
    end

    def current_images_count
      @current_images_count ||= ImageAlbumItem.where(user_id: user.id).count
    end

    def current_bytes_used
      @current_bytes_used ||= ImageAlbumItem.where(user_id: user.id).sum(:filesize).to_i
    end

    def current_mb_used
      (current_bytes_used / (1024.0 * 1024.0)).round(2)
    end

    def can_add_images?(count = 1)
      return false unless can_use_albums?
      return true if user.admin?

      return false if (current_images_count + count) > max_images

      if max_disk_mb > 0
        current_mb = current_mb_used
        return false if current_mb >= max_disk_mb
      end

      true
    end

    def album_has_capacity?(album, additional_count = 1)
      return true if user.admin?
      (album.images_count + additional_count) <= max_images_per_album
    end

    def to_h
      {
        can_use: can_use_albums?,
        used_images: current_images_count,
        max_images: max_images,
        used_bytes: current_bytes_used,
        used_mb: current_mb_used,
        max_disk_mb: max_disk_mb,
        max_per_album: max_images_per_album,
        can_download_zip: can_download_zip?,
        trust_level: user.trust_level,
        has_override: override.present?
      }
    end
  end
end
