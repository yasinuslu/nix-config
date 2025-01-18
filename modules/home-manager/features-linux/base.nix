{ pkgs, ... }:
{
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages =
    with pkgs;
    [
      coreutils-full
      iputils
      vlc
      copyq
      parsec-bin
      obs-studio
      bottles
      qbittorrent
      warp-terminal
      htop
      vesktop
      electron_27
      cloudflare-warp
      cloudflared
      lens
      mullvad-vpn
      tailscale
      telepresence2
      nixpkgs-review
      lazygit
      git-sync
    ]
    ++ (
      if pkgs.stdenv.system == "x86_64-linux" then
        [
          slack
          # zoom-us
          spotify
          lens
          logseq
          gitkraken
        ]
      else
        [ ]
    );

  services.spotifyd = {
    enable = true;
  };

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_DATA_DIRS = "$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:$HOME/share/flatpak/exports/share";
  };
}
