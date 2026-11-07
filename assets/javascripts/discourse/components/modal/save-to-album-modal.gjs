import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";

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
  @tracked existingAlbums = [];
  @tracked isCheckingExisting = false;

  constructor() {
    super(...arguments);
    this.title = this.args.model?.title || "";
    this.loadAlbums();
    this.checkExisting();
  }

  get photoUrl() {
    return this.args.model?.thumbnailUrl || this.args.model?.imageUrl;
  }

  get selectedAlbumName() {
    const album = this.albums.find(
      (a) => a.id.toString() === this.selectedAlbumId.toString()
    );
    return album ? album.name : "";
  }

  get existingAlbumNames() {
    return this.existingAlbums.map((a) => a.name);
  }

  get alreadyInAlbumMessage() {
    if (!this.existingAlbums.length) {
      return null;
    }
    if (this.existingAlbums.length === 1) {
      return i18n("image_album.save_modal.already_in_album_one", {
        album_name: this.existingAlbums[0].name,
      });
    }
    return i18n("image_album.save_modal.already_in_album_other", {
      album_names: this.existingAlbumNames.join(", "),
    });
  }

  async checkExisting() {
    this.isCheckingExisting = true;
    try {
      const res = await ajax("/image-album/items/check", {
        type: "GET",
        data: {
          image_url: this.args.model?.imageUrl,
          thumbnail_url: this.args.model?.thumbnailUrl,
          post_id: this.args.model?.postId,
        },
      });
      this.existingAlbums = res.existing_albums || [];
    } catch (e) {
      // non-critical
    } finally {
      this.isCheckingExisting = false;
    }
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
          thumbnail_url: this.args.model?.thumbnailUrl,
          post_id: this.args.model?.postId,
          title: this.title,
        },
      });

      if (res.already_saved) {
        const albumName = res.album_name || this.selectedAlbumName;
        this.toasts.info({
          duration: "short",
          data: {
            message: i18n("image_album.save_modal.already_saved_in_album", {
              album_name: albumName,
            }),
          },
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
              <strong>{{i18n "image_album.save_modal.preview_heading"}}</strong>
              <div style="font-size: 11px; color: var(--primary-medium); margin-top: 2px;">
                {{i18n "image_album.save_modal.preview_desc"}}
              </div>
            </div>
          </div>

          {{#if this.alreadyInAlbumMessage}}
            <div class="already-in-album-notice">
              <span class="notice-icon">{{icon "circle-info"}}</span>
              <span class="notice-text">{{this.alreadyInAlbumMessage}}</span>
            </div>
          {{/if}}

          {{#if this.isCreatingInline}}
            <div class="form-group">
              <label>{{i18n "image_album.save_modal.new_album_label"}}</label>
              <input
                type="text"
                value={{this.newAlbumName}}
                {{on "input" this.onNewAlbumNameInput}}
                placeholder={{i18n "image_album.save_modal.new_album_placeholder"}}
              />
              <div style="margin-top: 6px; display: flex; gap: 6px;">
                <DButton
                  @label="image_album.modal.create"
                  @action={{this.createAlbumInline}}
                  @disabled={{not this.newAlbumName}}
                  class="btn-primary btn-small"
                />
                <DButton
                  @label="image_album.modal.cancel"
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
              placeholder={{i18n "image_album.save_modal.photo_title_placeholder"}}
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
          @label="image_album.modal.cancel"
          @action={{@closeModal}}
          @disabled={{this.isSaving}}
          class="btn-flat"
        />
      </:footer>
    </DModal>
  </template>
}
