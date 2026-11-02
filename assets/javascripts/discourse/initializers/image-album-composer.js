import { withPluginApi } from "discourse/lib/plugin-api";
import AlbumManagerModal from "../components/modal/album-manager-modal";
import { i18n } from "discourse-i18n";
import bootbox from "bootbox";

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
          title: "image_album.composer.saved_photos_button_title",
          perform: (toolbarEvent) => {
            modal.show(AlbumManagerModal, {
              model: {
                composerMode: true,
                onInsert: (selectedItems) => {
                  const maxAllowed = siteSettings.max_images_per_post || 100;
                  if (selectedItems.length > maxAllowed) {
                    bootbox.alert(
                      i18n("image_album.composer.max_images_warning", {
                        max: maxAllowed,
                        selected: selectedItems.length,
                      })
                    );
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
      });
    });
  },
};
