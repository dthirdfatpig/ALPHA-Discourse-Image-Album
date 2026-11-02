# frozen_string_literal: true

module ::DiscourseImageAlbum
  class ImageAlbumUserOverride < ::ActiveRecord::Base
    self.table_name = "image_album_user_overrides"

    belongs_to :user

    validates :user_id, presence: true, uniqueness: true
    validates :max_images, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
    validates :max_disk_mb, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  end
end
