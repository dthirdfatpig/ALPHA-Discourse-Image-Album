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
      counts = instance_options && instance_options[:sub_albums_counts]
      if counts && counts.key?(object.id)
        counts[object.id]
      elsif object.association(:sub_albums).loaded?
        object.sub_albums.length
      else
        object.sub_albums.count
      end
    end
  end
end
