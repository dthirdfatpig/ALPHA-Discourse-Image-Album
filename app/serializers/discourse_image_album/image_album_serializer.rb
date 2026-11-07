# frozen_string_literal: true

module ::DiscourseImageAlbum
  class ImageAlbumSerializer < ::ApplicationSerializer
    attributes :id,
               :user_id,
               :parent_id,
               :name,
               :description,
               :images_count,
               :depth,
               :sub_albums_count,
               :created_at,
               :updated_at

    def sub_albums_count
      object.sub_albums.size
    end
  end
end
