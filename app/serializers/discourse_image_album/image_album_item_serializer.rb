# frozen_string_literal: true

module ::DiscourseImageAlbum
  class ImageAlbumItemSerializer < ::ApplicationSerializer
    attributes :id,
               :album_id,
               :user_id,
               :upload_id,
               :url,
               :thumb_url,
               :original_filename,
               :filesize,
               :width,
               :height,
               :title,
               :markdown_syntax,
               :source_post_id,
               :source_topic_id,
               :created_at

    def url
      object.url
    end

    def thumb_url
      object.thumb_url
    end

    def markdown_syntax
      object.markdown_syntax
    end
  end
end
