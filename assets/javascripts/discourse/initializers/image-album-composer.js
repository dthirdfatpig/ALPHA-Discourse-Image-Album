import { withPluginApi } from "discourse/lib/plugin-api";
import AlbumManagerModal from "../components/modal/album-manager-modal";
import { i18n } from "discourse-i18n";

export default {
  name: "image-album-composer",
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

      api.onToolbarCreate((toolbar) => {
        // Detect the exact group containing the emoji button
        let targetGroup = "extras";
        for (const g of toolbar.groups || []) {
          if (Array.isArray(g.buttons)) {
            const idx = g.buttons.findIndex(
              (b) => b.id === "emoji" || b.icon === "far-smile" || b.icon === "smile"
            );
            if (idx !== -1) {
              targetGroup = g.group;
              break;
            }
          }
        }

        toolbar.addButton({
          id: "image_album_saved_photos",
          group: targetGroup,
          icon: "images",
          className: "image-album-composer-btn",
          title: "image_album.composer.saved_photos_button_title",
          preventCollapse: true,
          perform: (toolbarEvent) => {
            modal.show(AlbumManagerModal, {
              model: {
                composerMode: true,
                onInsert: (selectedItems) => {
                  const maxAllowed = siteSettings.max_images_per_post || 100;
                  if (selectedItems.length > maxAllowed) {
                    const warnMsg = i18n("image_album.composer.max_images_warning", {
                      max: maxAllowed,
                      selected: selectedItems.length,
                    });
                    const dialog = api.container.lookup("service:dialog");
                    if (dialog && typeof dialog.alert === "function") {
                      dialog.alert(warnMsg);
                    } else {
                      window.alert(warnMsg);
                    }
                    return false;
                  }

                  const markdownSnippets = selectedItems
                    .map(
                      (item) =>
                        item.markdown_syntax ||
                        (item.url ? `![${item.title || "image"}](${item.url})` : "")
                    )
                    .filter(Boolean)
                    .join("\n\n");

                  if (markdownSnippets) {
                    let inserted = false;
                    if (toolbarEvent && typeof toolbarEvent.addText === "function") {
                      try {
                        toolbarEvent.addText("\n" + markdownSnippets + "\n");
                        inserted = true;
                      } catch (e) {
                        // Fallback below
                      }
                    }

                    if (!inserted) {
                      const composer = api.container.lookup("service:composer");
                      const model = composer?.model;
                      if (model) {
                        const current = model.reply || "";
                        if (typeof model.set === "function") {
                          model.set(
                            "reply",
                            (current ? current + "\n\n" : "") + markdownSnippets + "\n"
                          );
                        } else {
                          model.reply =
                            (current ? current + "\n\n" : "") + markdownSnippets + "\n";
                        }
                        inserted = true;
                      }
                    }

                    if (!inserted) {
                      try {
                        const appEvents = api.container.lookup("service:app-events");
                        if (appEvents) {
                          appEvents.trigger("composer:insert-block", markdownSnippets);
                        }
                      } catch (e) {
                        // ignore
                      }
                    }
                  }
                  return true;
                },
              },
            });
          },
        });

        // Position the button on the right side of the emoji button
        for (const g of toolbar.groups || []) {
          if (Array.isArray(g.buttons)) {
            const btnIdx = g.buttons.findIndex(
              (b) => b.id === "image_album_saved_photos"
            );
            const eIdx = g.buttons.findIndex(
              (b) => b.id === "emoji" || b.icon === "far-smile" || b.icon === "smile"
            );

            if (btnIdx !== -1 && eIdx !== -1) {
              const [albumBtn] = g.buttons.splice(btnIdx, 1);
              const updatedEIdx = g.buttons.findIndex(
                (b) => b.id === "emoji" || b.icon === "far-smile" || b.icon === "smile"
              );
              g.buttons.splice(updatedEIdx + 1, 0, albumBtn);
              break;
            }
          }
        }

        // DOM safeguard: move button next to emoji button in DOM once rendered
        if (typeof requestAnimationFrame === "function") {
          requestAnimationFrame(() => {
            const emojiBtn = document.querySelector(
              ".d-editor-button-bar .btn.emoji, .d-editor-button-bar button[data-format='emoji']"
            );
            const albumBtn = document.querySelector(
              ".d-editor-button-bar .image-album-composer-btn, .d-editor-button-bar button[data-format='image_album_saved_photos']"
            );
            if (emojiBtn && albumBtn && emojiBtn.parentNode) {
              emojiBtn.parentNode.insertBefore(albumBtn, emojiBtn.nextSibling);
            }
          });
        }
      });
    });
  },
};
