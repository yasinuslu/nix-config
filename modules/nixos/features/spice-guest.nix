{ pkgs, ... }:
{
  # Guest-specific SPICE services
  services.spice-vdagentd.enable = true;
  services.spice-autorandr.enable = true;
  services.spice-webdavd.enable = true;

  # X11 configuration for SPICE guest
  services.xserver = {
    # Note: virtio driver is handled by qemu-guest.nix
    displayManager.sessionCommands = ''
      ${pkgs.spice-vdagent}/bin/spice-vdagent
    '';
  };

  # Required packages for SPICE guest functionality
  environment.systemPackages = with pkgs; [
    spice-vdagent
  ];

  # Add SPICE-specific kernel module
  boot.kernelModules = [ "virtio_gpu" ];

  # Memory optimization for SPICE guest
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
  };
}
