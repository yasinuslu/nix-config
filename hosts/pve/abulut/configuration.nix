# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "pve-abulut";
  networking.firewall.enable = false;

  myNixOS = {
    mainUser = "abulut";

    gaming.enable = false;
    podman.enable = false;
    xserver-nvidia.enable = false;
    systemd-boot.enable = false;

    users = {
      abulut = {
        userConfig = {...}: {
          programs.git.userName = "Abdurrahim Bulut";
          programs.git.userEmail = "bulut.send@gmail.com";

          myHomeManager.docker.enable = false;
        };

        userSettings = {
          extraGroups = ["networkmanager" "wheel" "adbusers" "docker" "lxd" "kvm" "libvirtd" "spice"];
        };
      };
    };
  };
}