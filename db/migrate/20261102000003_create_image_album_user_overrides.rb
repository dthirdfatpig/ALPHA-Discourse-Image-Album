# frozen_string_literal: true

class CreateImageAlbumUserOverrides < ActiveRecord::Migration[6.1]
  def change
    create_table :image_album_user_overrides do |t|
      t.integer :user_id, null: false
      t.integer :max_images, null: true
      t.integer :max_disk_mb, null: true
      t.boolean :can_download_zip, null: true

      t.timestamps
    end

    add_index :image_album_user_overrides, :user_id, unique: true
  end
end
