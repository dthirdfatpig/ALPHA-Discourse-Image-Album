import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class SaveToAlbumModal extends Component {
  @service modal;
  @service toasts;

  @tracked albums = [];
  @tracked selectedAlbumId = "";
  @tracked title = "";
  @tracked isLoading = true;
  @tracked isSaving = false;
  @tracked isCreatingInline = false;
  @tracked newAlbumName = "";

  constructor() {
    super(...arguments);
    this.title = this.args.model?.title || "";
    this.loadAlbums();
  }

  get photoUrl() {
    return this.args.model?.thumbnailUrl || this.args.model?.imageUrl;
  }

  async loadAlbums() {
    this.isLoading = true;
    try {
      const res = await ajax("/image-album/albums");
      this.albums = res.albums || [];
      if (this.albums.length > 0) {
        this.selectedAlbumId = this.albums[0].id.toString();
      } else {
        this.isCreatingInline = true;
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  onAlbumChange(e) {
    this.selectedAlbumId = e.target.value;
  }

  @action
  onTitleInput(e) {
    this.title = e.target.value;
  }

  @action
  toggleCreateInline() {
    this.isCreatingInline = !this.isCreatingInline;
  }

  @action
  onNewAlbumNameInput(e) {
    this.newAlbumName = e.target.value;
  }

  @action
  async createAlbumInline() {
    const name = this.newAlbumName.trim();
    if (!name) {
      return;
    }

    try {
      const res = await ajax("/image-album/albums", {
        type: "POST",
        data: { name },
      });

      this.newAlbumName = "";
      this.isCreatingInline = false;
      await this.loadAlbums();
      if (res.album?.id) {
        this.selectedAlbumId = res.album.id.toString();
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async savePhoto() {
    const albumId = parseInt(this.selectedAlbumId, 10);
    if (!albumId) {
      return;
    }

    this.isSaving = true;
    try {
      const res = await ajax("/image-album/items/save-from-post", {
        type: "POST",
        data: {
          album_id: albumId,
          image_url: this.args.model?.imageUrl,
          post_id: this.args.model?.postId,
          title: this.title,
        },
      });

      if (res.already_saved) {
        this.toasts.info({
          duration: "short",
          data: { message: i18n("image_album.save_modal.already_saved") },
        });
      } else {
        this.toasts.success({
          duration: "short",
          data: { message: i18n("image_album.save_modal.success") },
        });
      }

      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "image_album.save_modal.title"}}
      @closeModal={{@closeModal}}
      class="save-to-album-modal"
    >
      <:body>
        <div class="save-modal-body">
          <div class="photo-preview-wrap">
            <img src={{this.photoUrl}} alt="Preview" />
            <div class="preview-info">
              <strong>Save Photo</strong>
              <div style="font-size: 11px; color: var(--primary-medium); margin-top: 2px;">
                Add this image to your private albums to view or re-use later.
              </div>
            </div>
          </div>

          {{#if this.isCreatingInline}}
            <div class="form-group">
              <label>New Album Name</label>
              <input
                type="text"
                value={{this.newAlbumName}}
                {{on "input" this.onNewAlbumNameInput}}
                placeholder="e.g. My Favorites, Wallpapers..."
              />
              <div style="margin-top: 6px; display: flex; gap: 6px;">
                <DButton
                  @label="Create"
                  @action={{this.createAlbumInline}}
                  @disabled={{not this.newAlbumName}}
                  class="btn-primary btn-small"
                />
                <DButton
                  @label="Cancel"
                  @action={{this.toggleCreateInline}}
                  class="btn-flat btn-small"
                />
              </div>
            </div>
          {{else}}
            <div class="form-group">
              <label>{{i18n "image_album.save_modal.choose_album"}}</label>
              <select {{on "change" this.onAlbumChange}} value={{this.selectedAlbumId}}>
                {{#each this.albums as |album|}}
                  <option value={{album.id}}>{{album.name}} ({{album.images_count}} photos)</option>
                {{/each}}
              </select>
            </div>

            <a href="#" class="create-inline-toggle" {{on "click" this.toggleCreateInline}}>
              {{i18n "image_album.save_modal.create_new_album"}}
            </a>
          {{/if}}

          <div class="form-group">
            <label>{{i18n "image_album.save_modal.photo_title"}}</label>
            <input
              type="text"
              value={{this.title}}
              {{on "input" this.onTitleInput}}
              placeholder="Optional photo title..."
            />
          </div>
        </div>
      </:body>

      <:footer>
        <DButton
          @label={{if this.isSaving "image_album.save_modal.saving" "image_album.save_modal.save_button"}}
          @action={{this.savePhoto}}
          @disabled={{or this.isSaving (not this.selectedAlbumId)}}
          class="btn-primary"
        />
        <DButton
          @label="Cancel"
          @action={{@closeModal}}
          @disabled={{this.isSaving}}
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
