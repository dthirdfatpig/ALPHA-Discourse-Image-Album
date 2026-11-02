# frozen_string_literal: true

module ::DiscourseImageAlbum
  class ImageAlbum < ::ActiveRecord::Base
    self.table_name = "image_albums"

    belongs_to :user
    belongs_to :parent, class_name: "::DiscourseImageAlbum::ImageAlbum", optional: true
    has_many :sub_albums, class_name: "::DiscourseImageAlbum::ImageAlbum", foreign_key: :parent_id, dependent: :destroy
    has_many :items, class_name: "::DiscourseImageAlbum::ImageAlbumItem", foreign_key: :album_id, dependent: :destroy

    validates :name, presence: true, length: { maximum: 120 }
    validate :validate_parent_ownership
    validate :validate_not_circular
    validate :validate_album_depth
    validate :validate_user_album_limit, on: :create

    scope :root_albums, -> { where(parent_id: nil) }

    def depth
      current = self
      level = 1
      while current.parent_id.present?
        current = current.parent
        level += 1
        break if level > 20 # Circuit breaker
      end
      level
    end

    def all_descendant_ids
      ids = []
      to_check = sub_albums.pluck(:id)
      while to_check.any?
        ids.concat(to_check)
        to_check = ImageAlbum.where(parent_id: to_check).pluck(:id)
      end
      ids
    end

    private

    def validate_parent_ownership
      return if parent_id.blank?

      p = parent
      if p.blank? || p.user_id != user_id
        errors.add(:parent_id, :invalid)
      end
    end

    def validate_not_circular
      return if parent_id.blank? || new_record?

      if parent_id == id || all_descendant_ids.include?(parent_id)
        errors.add(:parent_id, I18n.t("discourse_image_album.errors.cannot_move_into_self"))
      end
    end

    def validate_album_depth
      return if parent_id.blank?

      max_depth = SiteSetting.image_album_max_album_depth.to_i
      if depth > max_depth
        errors.add(:base, I18n.t("discourse_image_album.errors.album_depth_exceeded", max_depth: max_depth))
      end
    end

    def validate_user_album_limit
      return if user.blank? || user.admin?

      max_albums = SiteSetting.image_album_max_albums_per_user.to_i
      current_count = ImageAlbum.where(user_id: user_id).count
      if current_count >= max_albums
        errors.add(:base, I18n.t("discourse_image_album.errors.album_limit_reached", limit: max_albums))
      end
    end
  end
end
