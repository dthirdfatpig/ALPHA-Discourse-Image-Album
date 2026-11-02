# frozen_string_literal: true

class CreateImageAlbums < ActiveRecord::Migration[6.1]
  def change
    create_table :image_albums do |t|
      t.integer :user_id, null: false
      t.integer :parent_id, null: true
      t.string :name, null: false, limit: 120
      t.text :description
      t.integer :images_count, default: 0, null: false

      t.timestamps
    end

    add_index :image_albums, :user_id
    add_index :image_albums, :parent_id
    add_index :image_albums, [:user_id, :parent_id]
  end
end
