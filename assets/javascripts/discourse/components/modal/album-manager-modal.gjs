import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";

export default class AlbumManagerModal extends Component {
  @service modal;
  @service toasts;
  @service siteSettings;

  @tracked albums = [];
  @tracked activeAlbumId = null;
  @tracked items = [];
  @tracked selectedItemIds = new Set();
  @tracked isLoading = true;
  @tracked isLoadingItems = false;
  @tracked quota = null;

  // Pagination
  @tracked page = 1;
  @tracked totalPages = 1;
  @tracked totalCount = 0;

  // Creation / editing state
  @tracked isCreatingAlbum = false;
  @tracked newAlbumName = "";
  @tracked newAlbumIsSubAlbum = false;

  // Bulk move state
  @tracked showMoveSelect = false;
  @tracked moveTargetAlbumId = "";

  constructor() {
    super(...arguments);
    this.initData();
  }

  get activeAlbum() {
    return this.albums.find((a) => a.id === this.activeAlbumId) || null;
  }

  get selectedCount() {
    return this.selectedItemIds.size;
  }

  get hasSelection() {
    return this.selectedItemIds.size > 0;
  }

  get isComposerMode() {
    return Boolean(this.args.model?.composerMode);
  }

  get canDownloadZip() {
    if (!this.siteSettings.image_album_enable_whole_album_download) {
      return false;
    }
    if (this.quota && this.quota.can_download_zip === false) {
      return false;
    }
    return Boolean(this.activeAlbum && this.activeAlbum.images_count > 0);
  }

  get formattedQuotaText() {
    if (!this.quota) {
      return "";
    }
    const used = this.quota.used_images || 0;
    const max = this.quota.max_images || 10000;
    const mbUsed = this.quota.used_mb || 0;
    const maxMb = this.quota.max_disk_mb > 0 ? `${this.quota.max_disk_mb} MB` : i18n("image_album.modal.unlimited");
    return `${used} / ${max} photos (${mbUsed} MB / ${maxMb})`;
  }

  get quotaPercent() {
    if (!this.quota || !this.quota.max_images) {
      return 0;
    }
    return Math.min(100, Math.round(((this.quota.used_images || 0) / this.quota.max_images) * 100));
  }

  get otherAlbumsForMove() {
    return this.albums.filter((a) => a.id !== this.activeAlbumId);
  }

  async initData() {
    this.isLoading = true;
    try {
      await Promise.all([this.loadAlbums(), this.loadQuota()]);
      if (this.albums.length > 0) {
        await this.selectAlbum(this.albums[0].id);
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isLoading = false;
    }
  }

  async loadAlbums() {
    const response = await ajax("/image-album/albums");
    this.albums = response.albums || [];
  }

  async loadQuota() {
    const response = await ajax("/image-album/quota");
    this.quota = response.quota || null;
  }

  async loadItems(albumId, page = 1) {
    if (!albumId) {
      this.items = [];
      return;
    }
    this.isLoadingItems = true;
    try {
      const response = await ajax(`/image-album/albums/${albumId}/items`, {
        data: { page, limit: 50 },
      });
      this.items = response.items || [];
      this.page = response.meta?.page || 1;
      this.totalPages = response.meta?.total_pages || 1;
      this.totalCount = response.meta?.total_count || 0;
      this.selectedItemIds = new Set();
      this.showMoveSelect = false;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isLoadingItems = false;
    }
  }

  @action
  async selectAlbum(albumId) {
    this.activeAlbumId = albumId;
    this.page = 1;
    await this.loadItems(albumId, 1);
  }

  @action
  isItemSelected(itemId) {
    return Boolean(this.selectedItemIds && this.selectedItemIds.has(itemId));
  }

  @action
  onCardDoubleClick(item) {
    if (this.isComposerMode && this.args.model?.onInsert) {
      const ok = this.args.model.onInsert([item]);
      if (ok !== false) {
        this.args.closeModal();
      }
    }
  }

  @action
  onImageError(item, event) {
    if (event?.target && item.url && event.target.src !== item.url) {
      event.target.src = item.url;
    }
  }

  @action
  toggleItem(itemId) {
    const updated = new Set(this.selectedItemIds);
    if (updated.has(itemId)) {
      updated.delete(itemId);
    } else {
      updated.add(itemId);
    }
    this.selectedItemIds = updated;
  }

  @action
  selectAll() {
    const allIds = new Set(this.items.map((i) => i.id));
    this.selectedItemIds = allIds;
  }

  @action
  deselectAll() {
    this.selectedItemIds = new Set();
  }

  @action
  prevPage() {
    if (this.page > 1) {
      this.loadItems(this.activeAlbumId, this.page - 1);
    }
  }

  @action
  nextPage() {
    if (this.page < this.totalPages) {
      this.loadItems(this.activeAlbumId, this.page + 1);
    }
  }

  @action
  openCreateAlbum(isSubAlbum = false) {
    this.newAlbumIsSubAlbum = isSubAlbum;
    this.newAlbumName = "";
    this.isCreatingAlbum = true;
  }

  @action
  cancelCreateAlbum() {
    this.isCreatingAlbum = false;
    this.newAlbumName = "";
  }

  @action
  onNewAlbumNameInput(e) {
    this.newAlbumName = e.target.value;
  }

  @action
  async submitCreateAlbum() {
    const name = this.newAlbumName.trim();
    if (!name) {
      return;
    }

    try {
      const parentId = this.newAlbumIsSubAlbum ? this.activeAlbumId : null;
      const res = await ajax("/image-album/albums", {
        type: "POST",
        data: { name, parent_id: parentId },
      });

      this.isCreatingAlbum = false;
      this.newAlbumName = "";
      await this.loadAlbums();
      if (res.album?.id) {
        await this.selectAlbum(res.album.id);
      }
      this.toasts.success({
        duration: "short",
        data: { message: `Album "${name}" created.` },
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async deleteActiveAlbum() {
    if (!this.activeAlbum) {
      return;
    }

    const confirmed = window.confirm(
      i18n("image_album.modal.confirm_delete_album")
    );
    if (!confirmed) {
      return;
    }

    try {
      await ajax(`/image-album/albums/${this.activeAlbumId}`, {
        type: "DELETE",
      });
      this.toasts.success({
        duration: "short",
        data: { message: "Album deleted." },
      });
      await this.loadAlbums();
      await this.loadQuota();
      if (this.albums.length > 0) {
        await this.selectAlbum(this.albums[0].id);
      } else {
        this.activeAlbumId = null;
        this.items = [];
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  insertSelected() {
    const selected = this.items.filter((item) =>
      this.selectedItemIds.has(item.id)
    );

    if (this.args.model?.onInsert) {
      const ok = this.args.model.onInsert(selected);
      if (ok !== false) {
        this.args.closeModal();
      }
    }
  }

  @action
  toggleMoveSelect() {
    this.showMoveSelect = !this.showMoveSelect;
  }

  @action
  onTargetAlbumChange(e) {
    this.moveTargetAlbumId = e.target.value;
  }

  @action
  async executeMove() {
    const targetId = parseInt(this.moveTargetAlbumId, 10);
    if (!targetId) {
      return;
    }

    try {
      await ajax("/image-album/items/move", {
        type: "POST",
        data: {
          item_ids: Array.from(this.selectedItemIds),
          target_album_id: targetId,
        },
      });

      this.toasts.success({
        duration: "short",
        data: { message: `${this.selectedItemIds.size} photos moved successfully.` },
      });

      this.showMoveSelect = false;
      await this.loadAlbums();
      await this.loadItems(this.activeAlbumId, this.page);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async deleteSelected() {
    if (this.selectedItemIds.size === 0) {
      return;
    }

    const confirmed = window.confirm(
      i18n("image_album.modal.confirm_delete_items", {
        count: this.selectedItemIds.size,
      })
    );
    if (!confirmed) {
      return;
    }

    try {
      await ajax("/image-album/items/delete", {
        type: "POST",
        data: {
          item_ids: Array.from(this.selectedItemIds),
        },
      });

      this.toasts.success({
        duration: "short",
        data: { message: `${this.selectedItemIds.size} photos deleted.` },
      });

      await this.loadAlbums();
      await this.loadQuota();
      await this.loadItems(this.activeAlbumId, this.page);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  downloadAlbum() {
    if (!this.activeAlbumId) {
      return;
    }
    const downloadUrl = `/image-album/albums/${this.activeAlbumId}/download`;
    window.open(downloadUrl, "_blank");
  }

  <template>
    <DModal
      @title={{i18n "image_album.modal.title"}}
      @closeModal={{@closeModal}}
      class="album-manager-modal"
    >
      <:body>
        <div class="album-sidebar">
          <div class="sidebar-header">
            <h4>{{i18n "image_album.modal.albums_heading"}}</h4>
            <DButton
              @icon="folder-plus"
              @action={{fn this.openCreateAlbum false}}
              @title="image_album.modal.new_album"
              class="btn-small btn-flat"
            />
          </div>

          {{#if this.isCreatingAlbum}}
            <div class="new-album-form" style="padding: 6px; margin-bottom: 8px;">
              <input
                type="text"
                placeholder={{if this.newAlbumIsSubAlbum (i18n "image_album.modal.sub_album_name_placeholder") (i18n "image_album.modal.album_name_placeholder")}}
                value={{this.newAlbumName}}
                {{on "input" this.onNewAlbumNameInput}}
                style="width: 100%; margin-bottom: 6px;"
              />
              <div style="display: flex; gap: 4px;">
                <DButton
                  @label="image_album.modal.save"
                  @action={{this.submitCreateAlbum}}
                  class="btn-primary btn-small"
                />
                <DButton
                  @label="image_album.modal.cancel"
                  @action={{this.cancelCreateAlbum}}
                  class="btn-flat btn-small"
                />
              </div>
            </div>
          {{/if}}

          <ul class="album-tree">
            {{#each this.albums as |album|}}
              <li
                class="album-tree-item depth-{{album.depth}} {{if (eq album.id this.activeAlbumId) 'active'}}"
                {{on "click" (fn this.selectAlbum album.id)}}
              >
                <div class="album-name-wrap">
                  {{#if (eq album.id this.activeAlbumId)}}
                    {{icon "folder-open"}}
                  {{else}}
                    {{icon "folder"}}
                  {{/if}}
                  <span>{{album.name}}</span>
                </div>
                <span class="album-item-count">{{album.images_count}}</span>
              </li>
            {{/each}}
          </ul>

          {{#if this.quota}}
            <div class="quota-box">
              <div class="quota-title">
                <span>{{i18n "image_album.modal.storage_and_limit"}}</span>
                <span>{{this.quotaPercent}}%</span>
              </div>
              <div class="progress-bar">
                <div
                  class="fill {{if (gt this.quotaPercent 90) 'warning'}}"
                  style="width: {{this.quotaPercent}}%"
                ></div>
              </div>
              <div class="quota-details">{{this.formattedQuotaText}}</div>
            </div>
          {{/if}}
        </div>

        <div class="album-content">
          <div class="album-toolbar">
            <div class="album-breadcrumbs">
              <span class="bc-item">
                {{#if this.activeAlbum}}
                  {{this.activeAlbum.name}}
                {{else}}
                  {{i18n "image_album.modal.title"}}
                {{/if}}
              </span>
              {{#if this.activeAlbum}}
                <DButton
                  @icon="plus"
                  @label="image_album.modal.new_sub_album"
                  @action={{fn this.openCreateAlbum true}}
                  class="btn-small btn-flat"
                />
                <DButton
                  @icon="trash-can"
                  @action={{this.deleteActiveAlbum}}
                  @title="image_album.modal.delete_album"
                  class="btn-small btn-danger btn-flat"
                />
              {{/if}}
            </div>

            <div class="album-actions-group">
              {{#if this.canDownloadZip}}
                <DButton
                  @icon="download"
                  @label="image_album.modal.download_album"
                  @action={{this.downloadAlbum}}
                  class="btn-small btn-default"
                />
              {{/if}}

              {{#if (gt this.items.length 0)}}
                {{#if this.hasSelection}}
                  <DButton
                    @icon="square"
                    @label="image_album.modal.deselect_all"
                    @action={{this.deselectAll}}
                    class="btn-small btn-flat"
                  />
                {{else}}
                  <DButton
                    @icon="square-check"
                    @label="image_album.modal.select_all"
                    @action={{this.selectAll}}
                    class="btn-small btn-flat"
                  />
                {{/if}}
              {{/if}}

              {{#if this.hasSelection}}
                <DButton
                  @icon="arrow-right"
                  @label="image_album.modal.move_to"
                  @action={{this.toggleMoveSelect}}
                  class="btn-small btn-default"
                />

                <DButton
                  @icon="trash-can"
                  @label="image_album.modal.delete_selected"
                  @action={{this.deleteSelected}}
                  class="btn-small btn-danger"
                />
              {{/if}}

              {{#if this.isComposerMode}}
                <DButton
                  @icon="images"
                  @label="image_album.modal.insert_to_post"
                  @action={{this.insertSelected}}
                  @disabled={{not this.hasSelection}}
                  class="btn-small btn-primary"
                />
              {{/if}}
            </div>
          </div>

          {{#if this.showMoveSelect}}
            <div style="padding: 10px 18px; background: var(--tertiary-very-low, #f0f7fb); display: flex; align-items: center; gap: 8px;">
              <span>{{i18n "image_album.modal.move_to_prompt" count=this.selectedCount}}</span>
              <select {{on "change" this.onTargetAlbumChange}}>
                <option value="">{{i18n "image_album.modal.select_target_album"}}</option>
                {{#each this.otherAlbumsForMove as |tgt|}}
                  <option value={{tgt.id}}>{{tgt.name}}</option>
                {{/each}}
              </select>
              <DButton
                @label="image_album.modal.confirm_move"
                @action={{this.executeMove}}
                @disabled={{not this.moveTargetAlbumId}}
                class="btn-small btn-primary"
              />
            </div>
          {{/if}}

          <div class="photo-grid-scroll">
            {{#if this.isLoadingItems}}
              <div style="padding: 40px; text-align: center; color: var(--primary-medium);">
                {{i18n "image_album.modal.loading"}}
              </div>
            {{else if (eq this.items.length 0)}}
              <div class="empty-album-state">
                <div class="empty-icon">{{icon "images"}}</div>
                <h3>{{i18n "image_album.modal.no_photos"}}</h3>
                <p>{{i18n "image_album.modal.no_photos_hint"}}</p>
              </div>
            {{else}}
              <div class="photo-grid">
                {{#each this.items as |item|}}
                  <div
                    class="photo-card {{if (this.isItemSelected item.id) 'selected'}}"
                    {{on "click" (fn this.toggleItem item.id)}}
                    {{on "dblclick" (fn this.onCardDoubleClick item)}}
                  >
                    <div class="selection-checkbox">
                      {{#if (this.isItemSelected item.id)}}
                        {{icon "check"}}
                      {{/if}}
                    </div>
                    <img
                      src={{item.thumb_url}}
                      alt={{item.title}}
                      loading="lazy"
                      {{on "error" (fn this.onImageError item)}}
                    />
                    {{#if item.title}}
                      <div class="photo-overlay">{{item.title}}</div>
                    {{/if}}
                  </div>
                {{/each}}
              </div>
            {{/if}}
          </div>

          <div class="album-footer">
            <div class="selection-status">
              {{#if this.hasSelection}}
                {{i18n "image_album.modal.selected_count" count=this.selectedCount}}
              {{else}}
                {{i18n "image_album.modal.page_info" start=1 end=this.items.length total=this.totalCount}}
              {{/if}}
            </div>

            {{#if (gt this.totalPages 1)}}
              <div class="pagination-controls">
                <DButton
                  @label="image_album.modal.prev_page"
                  @action={{this.prevPage}}
                  @disabled={{eq this.page 1}}
                  class="btn-small btn-flat"
                />
                <span>{{i18n "image_album.modal.page_indicator" current=this.page total=this.totalPages}}</span>
                <DButton
                  @label="image_album.modal.next_page"
                  @action={{this.nextPage}}
                  @disabled={{eq this.page this.totalPages}}
                  class="btn-small btn-flat"
                />
              </div>
            {{/if}}
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
