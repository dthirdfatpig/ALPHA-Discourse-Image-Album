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
        toolbar.addButton({
          id: "image_album_saved_photos",
          group: "insertions",
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
                    .map((item) => item.markdown_syntax)
                    .filter(Boolean)
                    .join("\n\n");

                  if (markdownSnippets) {
                    toolbarEvent.addText("\n" + markdownSnippets + "\n");
                  }
                  return true;
                },
              },
            });
          },
        });

        // Ensure button is positioned directly next to the emoji button
        const insertionsGroup = toolbar.groups?.find((g) => g.group === "insertions");
        if (insertionsGroup && Array.isArray(insertionsGroup.buttons)) {
          const btnIdx = insertionsGroup.buttons.findIndex(
            (b) => b.id === "image_album_saved_photos"
          );
          const emojiIdx = insertionsGroup.buttons.findIndex(
            (b) => b.id === "emoji" || b.icon === "far-smile" || b.icon === "smile"
          );

          if (btnIdx !== -1 && emojiIdx !== -1) {
            const [albumBtn] = insertionsGroup.buttons.splice(btnIdx, 1);
            insertionsGroup.buttons.splice(emojiIdx + 1, 0, albumBtn);
          }
        }
      });
    });
  },
};
