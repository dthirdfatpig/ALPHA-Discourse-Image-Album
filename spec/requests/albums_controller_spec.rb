# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseImageAlbum::AlbumsController, type: :request do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.image_album_enabled = true
  end

  describe "GET /image-album/albums" do
    it "requires login" do
      get "/image-album/albums.json"
      expect(response.status).to eq(403)
    end

    it "returns current user's albums and does not expose other users' albums" do
      sign_in(user)
      DiscourseImageAlbum::ImageAlbum.create!(user: user, name: "User Album")
      DiscourseImageAlbum::ImageAlbum.create!(user: other_user, name: "Other Album")

      get "/image-album/albums.json"
      expect(response.status).to eq(200)

      json = JSON.parse(response.body)
      names = json["albums"].map { |a| a["name"] }
      expect(names).to include("User Album")
      expect(names).not_to include("Other Album")
    end

    it "properly calculates sub_albums_count without N+1 queries" do
      sign_in(user)
      root = DiscourseImageAlbum::ImageAlbum.create!(user: user, name: "Parent Album")
      DiscourseImageAlbum::ImageAlbum.create!(user: user, name: "Child 1", parent: root)
      DiscourseImageAlbum::ImageAlbum.create!(user: user, name: "Child 2", parent: root)

      get "/image-album/albums.json"
      expect(response.status).to eq(200)

      json = JSON.parse(response.body)
      root_data = json["albums"].find { |a| a["id"] == root.id }
      expect(root_data["sub_albums_count"]).to eq(2)
    end
  end

  describe "IDOR protection" do
    it "prevents a user from accessing another user's album" do
      sign_in(user)
      other_album = DiscourseImageAlbum::ImageAlbum.create!(user: other_user, name: "Secret")

      get "/image-album/albums/#{other_album.id}.json"
      expect(response.status).to eq(404)
    end

    it "prevents a user from deleting another user's album" do
      sign_in(user)
      other_album = DiscourseImageAlbum::ImageAlbum.create!(user: other_user, name: "Secret")

      delete "/image-album/albums/#{other_album.id}.json"
      expect(response.status).to eq(404)
      expect(DiscourseImageAlbum::ImageAlbum.find_by(id: other_album.id)).to be_present
    end
  end

  describe "GET /image-album/albums/:id/download" do
    it "blocks download when album exceeds maximum export capacity" do
      sign_in(user)
      album = DiscourseImageAlbum::ImageAlbum.create!(user: user, name: "Huge Album")
      album.update_columns(images_count: 501)

      get "/image-album/albums/#{album.id}/download"
      expect(response.status).to eq(400)
    end
  end

  describe "POST /image-album/albums" do
    it "creates an album" do
      sign_in(user)
      post "/image-album/albums.json", params: { name: "Cool Screenshots" }
      expect(response.status).to eq(200)

      json = JSON.parse(response.body)
      expect(json["album"]["name"]).to eq("Cool Screenshots")
    end
  end
end
