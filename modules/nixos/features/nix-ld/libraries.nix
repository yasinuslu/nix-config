{ pkgs, ... }:
let
  libwebp6-compat = pkgs.callPackage ./libwebp6-compat.nix { inherit pkgs; };
  libpcre3-deb = pkgs.callPackage ./libpcre3-deb.nix { inherit pkgs; };
in
{
  programs.nix-ld.libraries =
    with pkgs;
    [
      alsa-lib.out
      at-spi2-atk.out
      at-spi2-core.out
      atk
      cairo.out
      cups.lib
      curl
      dbus.lib
      enchant.out
      expat
      flite.lib
      fontconfig
      freetype
      fuse3
      gdk-pixbuf
      glib.debug
      glib.out
      gnutls.out
      gtk3
      harfbuzz.out
      harfbuzzFull.out
      hyphen.out
      icu
      icu66.out
      json-glib.out
      lcms.out
      libappindicator-gtk3
      libdrm
      libepoxy.out
      libevdev.out
      libevent.out
      libffi_3_3.out
      libgcc.lib
      libgcrypt.lib
      libgcrypt.out
      libGL
      libglvnd
      libgpg-error.out
      libgudev.out
      libjpeg8.out
      libnotify
      libopus.out
      libpcre3-deb.out
      libpng.out
      libpsl.out
      libpulseaudio
      libsecret.out
      libtasn1.out
      libunwind
      libusb1
      libuuid
      libwebp.out # libwebp.so.7
      libwebp6-compat.out # libwebp.so.6
      libxkbcommon.out
      libxml2
      libxslt.out
      mesa.out
      nghttp2.lib
      nspr.out
      nss_latest.out
      openssl
      pango.out
      pipewire
      sqlite.out
      stdenv.cc.cc
      systemd
      vulkan-loader
      woff2.lib
      xorg_sys_opengl.out
      xorg.libX11.out
      xorg.libxcb.out
      xorg.libXcomposite.out
      xorg.libXcursor.out
      xorg.libXdamage.out
      xorg.libXext.out
      xorg.libXfixes.out
      xorg.libXi.out
      xorg.libxkbfile.out
      xorg.libXrandr.out
      xorg.libXrender.out
      xorg.libXScrnSaver.out
      xorg.libxshmfence.out
      xorg.libXtst.out
      zlib.out
      zulip.out
    ]
    ++ (
      if pkgs.stdenv.system == "x86_64-linux" then
        [
          glamoroustoolkit.out
          steam-fhsenv-without-steam.out
        ]
      else
        [ ]
    );
}
