# Changelog

All notable changes to the **ALPHA Discourse Image Album** plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
