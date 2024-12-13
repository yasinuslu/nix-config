# Generated via dconf2nix: https://github.com/gvolpe/dconf2nix
{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {
    "org/gnome/shell" = {
      command-history = [ "r" ];
      disable-user-extensions = false;
      disabled-extensions = [ "extensions-sync@elhan.io" "apps-menu@gnome-shell-extensions.gcampax.github.com" "auto-move-windows@gnome-shell-extensions.gcampax.github.com" "launch-new-instance@gnome-shell-extensions.gcampax.github.com" "native-window-placement@gnome-shell-extensions.gcampax.github.com" ];
      enabled-extensions = [ "user-theme@gnome-shell-extensions.gcampax.github.com" "quick-settings-tweaks@qwreey" "appindicatorsupport@rgcjonas.gmail.com" "advanced-alt-tab@G-dH.github.com" ];
      favorite-apps = [ "google-chrome.desktop" "cursor.desktop" "lens-desktop.desktop" "org.gnome.Nautilus.desktop" "teams-for-linux.desktop" "jetbrains-datagrip-7d91d95e-427e-480c-843c-ba6f16b51474.desktop" ];
      last-selected-power-profile = "performance";
      welcome-dialog-last-shown-version = "43.2";
    };

    "extensions/advanced-alt-tab-window-switcher" = {
      animation-time-factor = 200;
      app-switcher-popup-raise-first-only = true;
      hot-edge-position = 2;
      hot-edge-width = 53;
      switcher-popup-activate-on-hide = true;
      switcher-popup-hover-select = true;
      switcher-popup-pointer = true;
      switcher-popup-scroll-in = 0;
      switcher-popup-shift-hotkeys = false;
      switcher-popup-status = false;
      switcher-popup-sync-filter = false;
      switcher-popup-timeout = 100;
      switcher-popup-tooltip-title = 2;
      switcher-ws-thumbnails = 2;
      win-switch-include-modals = false;
      win-switcher-popup-order = 2;
      win-switcher-popup-preview-size = 128;
      win-switcher-popup-scroll-item = 1;
      win-switcher-popup-sorting = 3;
      win-switcher-popup-titles = 1;
      win-switcher-single-prev-size = 192;
    };

    "extensions/pano" = {
      global-shortcut = [ "<Control><Alt>v" ];
    };

    "world-clocks" = {
      locations = [];
    };

  };
}
