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
