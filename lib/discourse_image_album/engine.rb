# frozen_string_literal: true

module ::DiscourseImageAlbum
  PLUGIN_NAME = "ALPHA-Discourse-Image-Album"

  class Engine < ::Rails::Engine
    engine_name "discourse_image_album"
    isolate_namespace DiscourseImageAlbum
  end
end
