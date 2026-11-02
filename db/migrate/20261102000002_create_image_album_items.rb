# frozen_string_literal: true

class CreateImageAlbumItems < ActiveRecord::Migration[6.1]
  def change
    create_table :image_album_items do |t|
      t.integer :album_id, null: false
      t.integer :user_id, null: false
      t.integer :upload_id, null: true
      t.text :image_url, null: true
      t.text :thumbnail_url, null: true
      t.string :original_filename, limit: 255
      t.bigint :filesize, default: 0, null: false
      t.integer :width
      t.integer :height
      t.integer :source_post_id, null: true
      t.integer :source_topic_id, null: true
      t.string :title, limit: 255

      t.timestamps
    end

    add_index :image_album_items, :album_id
    add_index :image_album_items, :user_id
    add_index :image_album_items, :upload_id
    add_index :image_album_items, [:album_id, :created_at]
    add_index :image_album_items, [:album_id, :id]
    add_index :image_album_items, [:user_id, :upload_id]
  end
end
