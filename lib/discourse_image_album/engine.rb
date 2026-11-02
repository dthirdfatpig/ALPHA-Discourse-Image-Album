# frozen_string_literal: true

module ::DiscourseImageAlbum
  PLUGIN_NAME = "ALPHA-Discourse-Image-Album"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseImageAlbum
  end
end
