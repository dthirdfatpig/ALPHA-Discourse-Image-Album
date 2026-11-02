# ALPHA Discourse Image Album

[![Version](https://img.shields.io/badge/version-0.1.2--alpha-blue.svg)](CHANGELOG.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Discourse Compatibility](https://img.shields.io/badge/discourse-2.8%2B%20%7C%203.x%20%7C%204.x-success.svg)](https://www.discourse.org)
[![AI Generated](https://img.shields.io/badge/built%20with-AI-blueviolet.svg)](#-ai-creation-disclosure)

> 🤖 **AI Creation Notice**: This plugin was generated and developed with AI assistance for Discourse communities seeking powerful, scalable personal photo album collections.

A high-performance personal **Photo Album & Image Bookmark** plugin for Discourse. Enables users to curate their own private image collections, organize photos with sub-albums, save forum images with a single click, and insert multiple saved images directly into the composer.

---

## ✨ Features

### 1. 🖼️ Composer Integration ("Saved Photos")
- Adds a dedicated **Photo Album** button directly to the Discourse composer toolbar.
- Opens the user's saved collections modal.
- Select one or multiple photos to insert directly into posts as standard Discourse markdown.
- **Enforces Discourse post limits**: Automatically checks and respects Discourse's `max_images_per_post` configuration with warning alerts.

### 2. 🔖 1-Click Forum Image Bookmarking ("Add to album")
- **Preserves Normal Behavior**: A regular click on any forum image still expands into Discourse's standard full-screen lightbox with all native options (download, view info, zoom, original image).
- Adds a sleek, non-intrusive **"Add to album"** action button on forum images and within the viewer.
- Choose destination album or create a new sub-album on the fly with optional captions.
- Works seamlessly across all topic streams.

### 3. 📁 Sub-Albums & Hierarchical Organization
- Organize images into nested **sub-albums** (up to configurable depth).
- Move photos between albums individually or in bulk.
- Tree-view navigation with real-time photo counts per folder.

### 4. 🚀 High-Capacity Scale (5,000+ Photos per Album)
- Engineered from the database up to comfortably support **over 5,000 pictures per album**.
- Offset/keyset database indexing (`[album_id, id DESC]`, `[album_id, created_at]`).
- Paginated retrieval (50–100 items per batch) with instant navigation so forum performance remains blazing fast.

### 5. ☑️ Bulk Management
- Multi-select photos with checkboxes.
- Bulk **Insert to Post**.
- Bulk **Move to Album**.
- Bulk **Delete**.

### 6. 📦 Whole Album ZIP Download
- Users can download their entire album as a single compressed `.zip` archive.
- Can be enabled or disabled globally by administrators or toggled per user.

### 7. 🔒 Privacy & Permissions
- **Private by Default**: Albums are strictly private to the user and invisible to other members.
- **Admin Visibility**: Forum administrators have full oversight for moderation and support.
- **Public Post Isolation**: When a user embeds an image from their album into a public topic, that image is naturally rendered and visible to everyone in the topic just like any standard Discourse upload.

### 8. 🛡️ Resilient & Isolated Architecture
- Isolated Rails Engine (`DiscourseImageAlbum::Engine`) and dedicated isolated tables (`image_albums`, `image_album_items`, `image_album_user_overrides`).
- Built with official Discourse Plugin API extension hooks (`withPluginApi`, Glimmer `.gjs` modals, and `decorateCookedElement`).
- Will **not break Discourse during or after core updates**.

---

## ⚙️ Plentiful Admin Settings

Configure under Discourse Admin &rarr; **Settings &rarr; Plugins &rarr; `image_album`**:

| Setting | Default | Description |
| :--- | :---: | :--- |
| `image_album_enabled` | `true` | Globally enable or disable the Image Album plugin. |
| `image_album_max_images_per_album` | `5000` | Maximum photos in a single album (supports 5,000+). |
| `image_album_max_total_images_per_user` | `20000` | Maximum photos a user can store across all albums. |
| `image_album_max_disk_quota_mb` | `2048` | Maximum storage space in MB per user (`0` = unlimited). |
| `image_album_allow_sub_albums` | `true` | Allow users to create nested sub-albums. |
| `image_album_max_album_depth` | `5` | Maximum nesting depth allowed for sub-albums. |
| `image_album_max_albums_per_user` | `100` | Maximum total number of albums a user can create. |
| `image_album_enable_whole_album_download`| `true` | Allow users to download whole albums as ZIP files. |
| `image_album_min_trust_level_to_use` | `0` | Minimum Trust Level required to use albums. |
| `image_album_max_images_tl0` | `100` | Maximum images for Trust Level 0 (new) users. |
| `image_album_max_images_tl1` | `500` | Maximum images for Trust Level 1 (basic) users. |
| `image_album_max_images_tl2` | `2500` | Maximum images for Trust Level 2 (member) users. |
| `image_album_max_images_tl3` | `10000` | Maximum images for Trust Level 3 (regular) users. |
| `image_album_max_images_tl4` | `50000` | Maximum images for Trust Level 4 (leader) users. |
| `image_album_allow_admin_custom_quotas` | `true` | Allow admins to override limits for specific users. |
| `image_album_max_bulk_selection` | `100` | Maximum items selectable in a single bulk operation. |
| `image_album_allow_external_hotlinks` | `true` | Allow bookmarking external image URLs to albums. |

### 👑 How Admins Can Configure Limits for Specific Users
Admins can easily override global storage and image count limits for specific users:
1. Navigate to Discourse **Admin** &rarr; **Users** &rarr; click on the desired user (e.g. `/admin/users/123/username`).
2. Under the user details, locate the dedicated **Photo Album Quotas** card.
3. Configure custom limits:
   - **Max Images**: Enter an image limit (e.g., `10000`) to override the user's Trust Level limit, or leave blank to follow site defaults.
   - **Max Storage (MB)**: Enter custom disk quota (e.g. `5120` for 5GB), or leave blank.
   - **Allow ZIP Downloads**: Choose *Site Default*, *Always Allow*, or *Always Deny*.
4. Click **Save Changes**. The custom limits will take effect immediately. To revert to defaults at any time, click **Remove Custom Limits**.

---

## 🚀 Installation

Add the repository URL to your `containers/app.yml` under the `plugins` hook:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/dthirdfatpig/ALPHA-Discourse-Image-Album.git
```

Rebuild your container:

```bash
cd /var/discourse
./launcher rebuild app
```

---

## 🤖 AI Creation Disclosure

This software was generated, designed, and structured using AI assistance for Discourse communities. All architecture follows Discourse best practices and isolation patterns to ensure ongoing upgrade safety.

---

## 📄 License

Released under the [MIT License](LICENSE).
