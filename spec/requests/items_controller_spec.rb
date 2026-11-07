# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseImageAlbum::ItemsController, type: :request do
  fab!(:user) { Fabricate(:user) }
  fab!(:album_a) { DiscourseImageAlbum::ImageAlbum.create!(user: user, name: "Album A") }
  fab!(:album_b) { DiscourseImageAlbum::ImageAlbum.create!(user: user, name: "Album B") }

  before do
    SiteSetting.image_album_enabled = true
    sign_in(user)
  end

  describe "POST /image-album/items/move" do
    it "moves items between albums and resets counter caches" do
      item1 = DiscourseImageAlbum::ImageAlbumItem.create!(album: album_a, user: user, image_url: "https://example.com/1.png")
      item2 = DiscourseImageAlbum::ImageAlbumItem.create!(album: album_a, user: user, image_url: "https://example.com/2.png")

      expect(album_a.reload.images_count).to eq(2)
      expect(album_b.reload.images_count).to eq(0)

      post "/image-album/items/move.json", params: {
        item_ids: [item1.id, item2.id],
        target_album_id: album_b.id,
      }

      expect(response.status).to eq(200)
      expect(album_a.reload.images_count).to eq(0)
      expect(album_b.reload.images_count).to eq(2)
      expect(item1.reload.album_id).to eq(album_b.id)
    end
  end

  describe "POST /image-album/items/delete" do
    it "deletes multiple items from album" do
      item1 = DiscourseImageAlbum::ImageAlbumItem.create!(album: album_a, user: user, image_url: "https://example.com/1.png")
      item2 = DiscourseImageAlbum::ImageAlbumItem.create!(album: album_a, user: user, image_url: "https://example.com/2.png")

      post "/image-album/items/delete.json", params: {
        item_ids: [item1.id],
      }

      expect(response.status).to eq(200)
      expect(album_a.reload.images_count).to eq(1)
      expect(DiscourseImageAlbum::ImageAlbumItem.find_by(id: item1.id)).to be_nil
    end
  end

  describe "GET /image-album/items/check" do
    it "returns existing albums containing the image" do
      DiscourseImageAlbum::ImageAlbumItem.create!(album: album_a, user: user, image_url: "https://example.com/check.png")

      get "/image-album/items/check.json", params: {
        image_url: "https://example.com/check.png",
      }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["already_saved"]).to eq(true)
      expect(json["existing_albums"]).to be_an(Array)
      expect(json["existing_albums"].first["name"]).to eq("Album A")
    end

    it "returns false when image is not in any album" do
      get "/image-album/items/check.json", params: {
        image_url: "https://example.com/not-saved.png",
      }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["already_saved"]).to eq(false)
      expect(json["existing_albums"]).to be_empty
    end
  end
end
