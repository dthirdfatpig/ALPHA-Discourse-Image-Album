# frozen_string_literal: true
# name: ALPHA-Discourse-Image-Album
# about: Personal photo album system for Discourse users with sub-albums, composer integration, 1-click photo saving, bulk management, and comprehensive admin quotas.
# version: 0.1.8-alpha
# authors: AI Assistant & dthirdfatpig
# url: https://github.com/dthirdfatpig/ALPHA-Discourse-Image-Album
# required_version: 2.7.0

enabled_site_setting :image_album_enabled

register_asset "stylesheets/common/discourse-image-album.scss"

register_svg_icon "images"
register_svg_icon "folder"
register_svg_icon "folder-plus"
register_svg_icon "folder-open"
register_svg_icon "download"
register_svg_icon "cloud-arrow-down"
register_svg_icon "arrow-right"
register_svg_icon "trash-can"
register_svg_icon "star"
register_svg_icon "bookmark"
register_svg_icon "plus"
register_svg_icon "layer-group"
register_svg_icon "check"
register_svg_icon "eye"
register_svg_icon "xmark"

after_initialize do
  # Fix for uppercase plugin names and strict stylesheet MIME checking in modern browsers.
  Discourse::Application.routes.prepend do
    get "stylesheets/:name" => "stylesheets#show_source_map",
      constraints: {
        name: /[-a-zA-Z0-9_]+/,
        format: /css\.map/,
      },
      format: true

    get "stylesheets/:name" => "stylesheets#show",
      constraints: {
        name: /[-a-zA-Z0-9_]+/,
        format: "css",
      },
      format: true
  end

  require_relative "lib/discourse_image_album/engine"
  require_relative "lib/discourse_image_album/quota_calculator"
  require_relative "lib/discourse_image_album/zip_exporter"
  require_relative "app/models/discourse_image_album/image_album"
  require_relative "app/models/discourse_image_album/image_album_item"
  require_relative "app/models/discourse_image_album/image_album_user_override"
  require_relative "app/serializers/discourse_image_album/image_album_serializer"
  require_relative "app/serializers/discourse_image_album/image_album_item_serializer"
  require_relative "app/serializers/discourse_image_album/user_album_quota_serializer"
  require_relative "app/controllers/discourse_image_album/albums_controller"
  require_relative "app/controllers/discourse_image_album/items_controller"
  require_relative "app/controllers/discourse_image_album/admin_controller"
  require_relative "config/routes"

  Discourse::Application.routes.append do
    mount ::DiscourseImageAlbum::Engine, at: "/image-album"
  end

  add_to_serializer(:current_user, :can_use_image_albums) do
    return false unless SiteSetting.image_album_enabled
    ::DiscourseImageAlbum::QuotaCalculator.for_user(object).can_use_albums?
  end
end
