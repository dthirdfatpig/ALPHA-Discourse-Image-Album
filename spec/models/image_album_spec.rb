# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseImageAlbum::ImageAlbum, type: :model do
  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.image_album_enabled = true
    SiteSetting.image_album_max_albums_per_user = 5
    SiteSetting.image_album_max_album_depth = 3
  end

  describe "validations and hierarchy" do
    it "creates a root album successfully" do
      album = described_class.create!(user: user, name: "Memes")
      expect(album.depth).to eq(1)
      expect(album.parent_id).to be_nil
    end

    it "creates nested sub-albums" do
      root = described_class.create!(user: user, name: "Root")
      child = described_class.create!(user: user, name: "Child", parent: root)
      grandchild = described_class.create!(user: user, name: "Grandchild", parent: child)

      expect(child.depth).to eq(2)
      expect(grandchild.depth).to eq(3)
    end

    it "prevents exceeding maximum hierarchy depth" do
      root = described_class.create!(user: user, name: "L1")
      l2 = described_class.create!(user: user, name: "L2", parent: root)
      l3 = described_class.create!(user: user, name: "L3", parent: l2)

      l4 = described_class.new(user: user, name: "L4", parent: l3)
      expect(l4).not_to be_valid
      expect(l4.errors[:base]).to be_present
    end

    it "prevents circular parent assignment" do
      album1 = described_class.create!(user: user, name: "A1")
      album2 = described_class.create!(user: user, name: "A2", parent: album1)

      album1.parent = album2
      expect(album1).not_to be_valid
      expect(album1.errors[:parent_id]).to be_present
    end

    it "enforces user album count limit" do
      5.times do |i|
        described_class.create!(user: user, name: "Album #{i}")
      end

      sixth = described_class.new(user: user, name: "Exceeded")
      expect(sixth).not_to be_valid
      expect(sixth.errors[:base]).to be_present
    end
  end
end
