# Changelog

All notable changes to the **ALPHA Discourse Image Album** plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.7-alpha] - 2026-11-02

### Added
- **Hold-to-Preview Enlarged Overlay**: Long-press on mobile touch or press-and-hold on desktop over any photo in the album to display an enlarged high-resolution preview dialog. Inspect fine details, view dimensions, toggle selection, or insert directly into post without leaving preview.
- **Quick Preview Action**: Added an eye icon button on each photo card for an instant single-click preview alternative.

### Changed
- **Gallery Grid Sizing & Density**:
  - Desktop thumbnail grid resized to dynamic columns (`minmax(130px, 1fr)`) with 10px spacing for clarity.
  - Mobile layout updated to 4 columns edge-to-edge with 3px spacing, matching native gallery applications and making photos significantly clearer.

## [0.1.6-alpha] - 2026-11-02

### Added
- **Always-Visible Star Button on Forum Images**: Replaced hover-dependent floating bookmark with an always-visible circular star button (`d-icon-star`) directly on topic images, eliminating the need to long-press or dismiss context menus on mobile devices.
- **Dense High-Capacity Gallery Grid**:
  - Desktop layout increased to **6 columns per row**.
  - Mobile layout increased to **5 columns per row** with optimized touch targets and compact indicators.
  - Mobile album sidebar automatically adapts into a horizontal scrolling drawer to maximize screen real estate for photos.

### Changed
- **Own-Image Exclusion**: The "Add to album" star button now automatically excludes images in the current user's own posts, appearing exclusively on other members' photos.

## [0.1.5-alpha] - 2026-11-02

### Fixed
- **S3 & Cloudflare R2 URL Cooking (400 Bad Request Fix)**: Resolved 400 Bad Request errors on Cloudflare R2 / S3 storage endpoints by routing URLs through `UrlHelper.cook_url`, `Discourse.store.cdn_url`, and applying configured S3 CDN domains (`s3_cdn_url`).
- **Private S3/R2 Delivery Fallback**: Added fallback to Discourse's internal `upload.short_path` when accessing private Cloudflare R2 buckets without a CDN, ensuring images are safely delivered via Discourse's upload controller.
- **Client Thumbnail Preservation**: `SaveToAlbumModal` now sends the currently visible post thumbnail URL on save, ensuring instant fallback preview availability.
- **Image Error Auto-Recovery**: Photo grid images automatically attempt to fallback to the full image URL if a thumbnail fails to load.

### Added
- **Discourse Optimized Image Thumbnails**: Photo album grid now leverages Discourse's native optimized image derivatives (`upload.optimized_images`) instead of loading heavy raw originals, dramatically speeding up album viewing and saving bandwidth.

## [0.1.4-alpha] - 2026-11-02

### Fixed
- **Photo Grid Glimmer Render Fix**: Fixed `TypeError: Method Set.prototype.has called on incompatible receiver undefined` by binding selection check to component action `isItemSelected` instead of detached template helper execution.
- **Composer Markdown Insertion Fallback**: Added fallback to `composer.model` reply attribute to ensure images are always inserted into posts even if the toolbar event context is lost.

### Added
- **Double-Click Quick Insert**: Users can now double-click any photo card in composer mode to immediately insert it into their topic.

## [0.1.3-alpha] - 2026-11-02

### Fixed
- **Bootstrap / Migration Fix**: Resolved `bundle exec rake db:migrate` failure during container rebuild caused by duplicate engine mounting and invalid application-level route drawing.
- **Engine Route Loading**: Guaranteed proper initialization of `DiscourseImageAlbum::Engine.routes` within Discourse's standard `after_initialize` lifecycle.

## [0.1.2-alpha] - 2026-11-02

### Fixed
- **Rails Engine & Routing Resolution (404 Fix)**: Fixed 404 errors on `/image-album/quota`, `/image-album/albums`, and API endpoints by declaring the Rails engine at plugin load time and adding direct application-level route scoping.
- **Modal Button I18n Labels**: Resolved `[en.Save]`, `[en.Cancel]`, `[en.Create]`, and missing translation keys by binding explicit namespaced localization keys on all modal actions and placeholders.

### Changed
- **Composer Button Positioning**: Moved the "Photo album" button to the right side of the Emoji button in both toolbar configuration and DOM rendering.
- **Button Hover Title**: Shortened hover tooltip text to "Photo album" (localized per user language).

## [0.1.1-alpha] - 2026-11-02

### Fixed
- **Bootbox Dependency Resolution**: Removed legacy `bootbox` module dependency that caused plugin asset bundle evaluation failure on modern Discourse instances.

### Changed
- **Composer Button Placement**: Positioned the "Saved Photos" toolbar button directly next to the emoji button on the main toolbar row, with permanent visibility rules to prevent collapsing into the options popup menu.

### Added
- **Admin User Details UI Connector**: Added a native `admin-user-details` panel on user admin profiles (`/admin/users/:id/:username`) allowing forum administrators to configure custom per-user image limits, disk space quotas, and ZIP download permissions.

## [0.1.0-alpha] - 2026-11-02

### Added
- **Composer Integration**: Dedicated toolbar button to open saved photo albums and insert one or multiple photos directly into topics.
- **Max Post Image Enforcement**: Automatically validates against Discourse's `max_images_per_post` setting when inserting images.
- **1-Click Photo Saving ("Add to album")**: Non-intrusive floating bookmark button on forum post images and lightbox viewer, preserving native click-to-expand lightbox behavior.
- **Sub-Albums & Hierarchy**: Support for nested sub-albums with depth validation and circular reference protection.
- **High-Capacity Scalability**: Optimized database schema with indexing and pagination designed to handle 5,000+ photos per album effortlessly.
- **Bulk Operations**: Multi-selection for bulk insertion into posts, moving between albums, and bulk deletion with counter cache synchronization.
- **Whole Album ZIP Download**: Export and download entire albums as compressed ZIP archives (streaming / tempfile).
- **Privacy Controls**: Albums are private to individual users while accessible to administrators for moderation; posted album photos render publicly in topics.
- **Plentiful Admin Settings**:
  - Global and Trust Level tiered image quotas (TL0 through TL4).
  - Disk storage limit (MB) quota calculation.
  - Sub-album depth and album count limits.
  - Whole album download toggle.
  - Per-user admin override table (`image_album_user_overrides`).
  - External hotlink allowance setting.
- **Discourse Isolation & Upgrade Safety**:
  - Built within namespaced Rails Engine `DiscourseImageAlbum::Engine`.
  - Modern Glimmer `.gjs` DModal dialogs compatible with Discourse 2.8+ through 4.x.
  - Uppercase/lowercase stylesheet routing fallback protection.
- **Full Test Suite**: Model and controller request specs for albums, items, hierarchy, and bulk operations.
