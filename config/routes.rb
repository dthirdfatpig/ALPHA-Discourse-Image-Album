# frozen_string_literal: true

DiscourseImageAlbum::Engine.routes.draw do
  get "/albums" => "albums#index"
  post "/albums" => "albums#create"
  get "/albums/:id" => "albums#show"
  put "/albums/:id" => "albums#update"
  delete "/albums/:id" => "albums#destroy"
  get "/albums/:id/download" => "albums#download"

  get "/albums/:album_id/items" => "items#index"
  post "/albums/:album_id/items" => "items#create"
  post "/items/save-from-post" => "items#save_from_post"
  post "/items/move" => "items#move"
  post "/items/delete" => "items#destroy_multiple"
  delete "/items/:id" => "items#destroy"

  get "/quota" => "albums#quota"

  # Admin overrides
  get "/admin/overrides" => "admin#index"
  get "/admin/overrides/:user_id" => "admin#show"
  post "/admin/overrides" => "admin#save_override"
  delete "/admin/overrides/:user_id" => "admin#delete_override"
end

Discourse::Application.routes.draw do
  mount ::DiscourseImageAlbum::Engine, at: "/image-album"
end
