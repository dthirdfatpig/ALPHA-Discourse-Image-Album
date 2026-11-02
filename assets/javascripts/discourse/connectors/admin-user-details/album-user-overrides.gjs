import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import icon from "discourse-common/helpers/d-icon";

export default class AlbumUserOverrides extends Component {
  @service toasts;
  @service siteSettings;

  @tracked isLoading = true;
  @tracked isSaving = false;
  @tracked maxImages = "";
  @tracked maxDiskMb = "";
  @tracked canDownloadZip = "";
  @tracked quota = null;
  @tracked hasOverride = false;

  get targetUser() {
    return this.args.outletArgs?.user || this.args.outletArgs?.model || null;
  }

  constructor() {
    super(...arguments);
    this.loadUserData();
  }

  async loadUserData() {
    if (!this.targetUser?.id) {
      this.isLoading = false;
      return;
    }

    this.isLoading = true;
    try {
      const res = await ajax(`/image-album/admin/overrides/${this.targetUser.id}`);
      this.quota = res.quota || null;
      if (res.override) {
        this.hasOverride = true;
        this.maxImages = res.override.max_images != null ? res.override.max_images.toString() : "";
        this.maxDiskMb = res.override.max_disk_mb != null ? res.override.max_disk_mb.toString() : "";
        if (res.override.can_download_zip === true) {
          this.canDownloadZip = "true";
        } else if (res.override.can_download_zip === false) {
          this.canDownloadZip = "false";
        } else {
          this.canDownloadZip = "";
        }
      } else {
        this.hasOverride = false;
        this.maxImages = "";
        this.maxDiskMb = "";
        this.canDownloadZip = "";
      }
    } catch (e) {
      // If error (e.g. 404), continue gracefully
    } finally {
      this.isLoading = false;
    }
  }

  @action
  onMaxImagesInput(e) {
    this.maxImages = e.target.value;
  }

  @action
  onMaxDiskMbInput(e) {
    this.maxDiskMb = e.target.value;
  }

  @action
  onDownloadZipChange(e) {
    this.canDownloadZip = e.target.value;
  }

  @action
  async saveOverride() {
    if (!this.targetUser?.id) {
      return;
    }

    this.isSaving = true;
    try {
      const data = {
        user_id: this.targetUser.id,
        max_images: this.maxImages.trim() !== "" ? parseInt(this.maxImages, 10) : null,
        max_disk_mb: this.maxDiskMb.trim() !== "" ? parseInt(this.maxDiskMb, 10) : null,
      };

      if (this.canDownloadZip === "true") {
        data.can_download_zip = true;
      } else if (this.canDownloadZip === "false") {
        data.can_download_zip = false;
      } else {
        data.can_download_zip = "";
      }

      await ajax("/image-album/admin/overrides", {
        type: "POST",
        data,
      });

      this.hasOverride = true;
      this.toasts.success({
        duration: "short",
        data: { message: i18n("image_album.admin.override_saved") },
      });
      await this.loadUserData();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  @action
  async clearOverride() {
    if (!this.targetUser?.id) {
      return;
    }

    this.isSaving = true;
    try {
      await ajax(`/image-album/admin/overrides/${this.targetUser.id}`, {
        type: "DELETE",
      });

      this.hasOverride = false;
      this.maxImages = "";
      this.maxDiskMb = "";
      this.canDownloadZip = "";

      this.toasts.success({
        duration: "short",
        data: { message: i18n("image_album.admin.override_deleted") },
      });
      await this.loadUserData();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    {{#if this.siteSettings.image_album_enabled}}
      <div class="admin-album-overrides-card">
        <div class="card-header">
          <div class="card-title">
            {{icon "images"}}
            <span>{{i18n "image_album.admin.user_section_title"}}</span>
          </div>
          {{#if this.hasOverride}}
            <span class="custom-badge">{{i18n "image_album.admin.custom_active_badge"}}</span>
          {{/if}}
        </div>

        <p class="card-desc">{{i18n "image_album.admin.user_section_desc"}}</p>

        {{#if this.isLoading}}
          <div class="loading-wrap">{{i18n "image_album.modal.loading"}}</div>
        {{else}}
          {{#if this.quota}}
            <div class="quota-summary-pills">
              <span class="pill">
                <strong>{{i18n "image_album.admin.current_usage_label"}}</strong> {{this.quota.used_images}} photos ({{this.quota.used_mb}} MB)
              </span>
              <span class="pill">
                <strong>{{i18n "image_album.admin.effective_limit_label"}}</strong> {{this.quota.max_images}} photos
              </span>
            </div>
          {{/if}}

          <div class="override-grid">
            <div class="override-field">
              <label>{{i18n "image_album.admin.max_images_label"}}</label>
              <input
                type="number"
                min="0"
                placeholder={{i18n "image_album.admin.max_images_placeholder"}}
                value={{this.maxImages}}
                {{on "input" this.onMaxImagesInput}}
              />
            </div>

            <div class="override-field">
              <label>{{i18n "image_album.admin.max_disk_mb_label"}}</label>
              <input
                type="number"
                min="0"
                placeholder={{i18n "image_album.admin.max_disk_mb_placeholder"}}
                value={{this.maxDiskMb}}
                {{on "input" this.onMaxDiskMbInput}}
              />
            </div>

            <div class="override-field">
              <label>{{i18n "image_album.admin.can_download_label"}}</label>
              <select {{on "change" this.onDownloadZipChange}} value={{this.canDownloadZip}}>
                <option value="">{{i18n "image_album.admin.default_choice"}}</option>
                <option value="true">{{i18n "image_album.admin.always_allow"}}</option>
                <option value="false">{{i18n "image_album.admin.always_deny"}}</option>
              </select>
            </div>
          </div>

          <div class="card-actions">
            <DButton
              @icon="check"
              @label="image_album.admin.save_override"
              @action={{this.saveOverride}}
              @disabled={{this.isSaving}}
              class="btn-primary btn-small"
            />
            {{#if this.hasOverride}}
              <DButton
                @icon="trash-can"
                @label="image_album.admin.delete_override"
                @action={{this.clearOverride}}
                @disabled={{this.isSaving}}
                class="btn-danger btn-small"
              />
            {{/if}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
