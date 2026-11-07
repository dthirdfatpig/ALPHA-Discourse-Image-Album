import { withPluginApi } from "discourse/lib/plugin-api";
import SaveToAlbumModal from "../components/modal/save-to-album-modal";
import { i18n } from "discourse-i18n";
import { iconHTML } from "discourse-common/lib/icon-library";

export default {
  name: "image-album-lightbox",
  initialize() {
    withPluginApi("1.6.0", (api) => {
      const currentUser = api.getCurrentUser();
      const siteSettings = api.container.lookup("service:site-settings");
      const modal = api.container.lookup("service:modal");

      if (!currentUser || !siteSettings.image_album_enabled) {
        return;
      }

      const minTL = siteSettings.image_album_min_trust_level_to_use || 0;
      if (currentUser.trust_level < minTL && !currentUser.staff) {
        return;
      }

      // Decorate images in cooked post streams
      api.decorateCookedElement((cooked, helper) => {
        if (!cooked) {
          return;
        }

        const post = helper ? helper.getModel() : null;
        const postId = post ? post.id : null;
        const postTitle = post && post.topic ? post.topic.title : document.title;

        // Targets: lightbox wrappers or standalone post images
        const imageContainers = cooked.querySelectorAll(".lightbox-wrapper, p > img, div > img");

        imageContainers.forEach((container) => {
          // Skip if already decorated
          if (container.querySelector(".image-album-save-btn")) {
            return;
          }

          let img = container.tagName === "IMG" ? container : container.querySelector("img");
          if (!img) {
            return;
          }

          // Skip tiny images, emojis, and avatars
          if (
            img.classList.contains("avatar") ||
            img.classList.contains("emoji") ||
            img.classList.contains("site-icon") ||
            (img.width && img.width < 60) ||
            (img.height && img.height < 60)
          ) {
            return;
          }

          // Retrieve best available high-res image URL
          let imageUrl = null;
          const parentAnchor = img.closest("a.lightbox");
          if (parentAnchor && parentAnchor.href) {
            imageUrl = parentAnchor.href;
          } else {
            imageUrl = img.currentSrc || img.src;
          }

          if (!imageUrl) {
            return;
          }

          // Create "Add to album" floating star button
          const saveBtn = document.createElement("button");
          saveBtn.type = "button";
          saveBtn.className = "image-album-save-btn";
          saveBtn.setAttribute("aria-label", i18n("image_album.lightbox.add_to_album"));
          saveBtn.title = i18n("image_album.lightbox.add_to_album");
          saveBtn.innerHTML = iconHTML("star");

          // Handle click/touch without triggering image lightbox zoom
          saveBtn.addEventListener("click", (e) => {
            e.preventDefault();
            e.stopPropagation();

            modal.show(SaveToAlbumModal, {
              model: {
                imageUrl: imageUrl,
                postId: postId,
                title: img.alt || postTitle || "Saved Photo",
                thumbnailUrl: img.src || imageUrl,
              },
            });
          });

          saveBtn.addEventListener("touchend", (e) => {
            e.stopPropagation();
          });

          // Append button to container
          if (container.classList.contains("lightbox-wrapper")) {
            container.appendChild(saveBtn);
          } else {
            // Standalone image: ensure position relative wrapper
            const wrapper = document.createElement("span");
            wrapper.style.position = "relative";
            wrapper.style.display = "inline-block";
            img.parentNode.insertBefore(wrapper, img);
            wrapper.appendChild(img);
            wrapper.appendChild(saveBtn);
          }
        });
      });
    });
  },
};
