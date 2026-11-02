# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseImageAlbum::ImageAlbumItem, type: :model do
  fab!(:user) { Fabricate(:user) }
  fab!(:album) { DiscourseImageAlbum::ImageAlbum.create!(user: user, name: "Wallpapers") }
  fab!(:upload) { Fabricate(:upload, user: user, original_filename: "wallpaper.png", width: 1920, height: 1080) }

  before do
    SiteSetting.image_album_enabled = true
    SiteSetting.image_album_max_images_per_album = 5000
    SiteSetting.image_album_max_total_images_per_user = 20000
  end

  it "creates an item linked to an upload and increments counter cache" do
    expect {
      described_class.create!(
        album: album,
        user: user,
        upload: upload
      )
    }.to change { album.reload.images_count }.by(1)

    item = album.items.last
    expect(item.original_filename).to eq("wallpaper.png")
    expect(item.width).to eq(1920)
    expect(item.markdown_syntax).to include("![wallpaper.png|1920x1080]")
  end

  it "creates an item linked to an external image URL" do
    item = described_class.create!(
      album: album,
      user: user,
      image_url: "https://example.com/photo.jpg",
      title: "Nature Shot"
    )

    expect(item.url).to eq("https://example.com/photo.jpg")
    expect(item.markdown_syntax).to eq("![Nature Shot](https://example.com/photo.jpg)")
  end

  describe ".cook_url" do
    it "rewrites S3 / R2 endpoints to S3 CDN URL when configured" do
      SiteSetting.s3_cdn_url = "https://cdn.example.com"
      SiteSetting.s3_endpoint = "https://account123.r2.cloudflarestorage.com"
      SiteSetting.s3_bucket = "mybucket"

      cooked = described_class.cook_url("//mybucket.account123.r2.cloudflarestorage.com/optimized/1X/image.jpg")
      expect(cooked).to eq("https://cdn.example.com/optimized/1X/image.jpg")
    end

    it "falls back to upload short_path if private R2 endpoint has no CDN" do
      SiteSetting.s3_cdn_url = ""
      fake_upload = Fabricate(:upload, user: user)

      cooked = described_class.cook_url("//mybucket.account123.r2.cloudflarestorage.com/original/1X/secret.jpg", upload: fake_upload)
      expect(cooked).to eq("#{Discourse.base_url}#{fake_upload.short_path}")
    end
  end
end
