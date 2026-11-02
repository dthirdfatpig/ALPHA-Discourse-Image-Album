# frozen_string_literal: true

module ::DiscourseImageAlbum
  class UserAlbumQuotaSerializer < ::ApplicationSerializer
    attributes :can_use,
               :used_images,
               :max_images,
               :used_bytes,
               :used_mb,
               :max_disk_mb,
               :max_per_album,
               :can_download_zip,
               :trust_level,
               :has_override
  end
end
