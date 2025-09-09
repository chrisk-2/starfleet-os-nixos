{ config, lib, pkgs, ... }:

{
  # Base configuration for all node types
  
  # Use systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Enable networking
  networking.networkmanager.enable = true;
  
  # Set timezone
  time.timeZone = "America/New_York";
  
  # Configure locale
  i18n.defaultLocale = "en_US.UTF-8";
  
  # Enable sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;
  
  # Enable printing
  services.printing.enable = true;
  
  # Enable SSH
  services.openssh.enable = true;
  
  # Enable firewall
  networking.firewall.enable = true;
  
  # Configure automatic upgrades
  system.autoUpgrade.enable = true;
  
  # Enable NixOS manual
  documentation.nixos.enable = true;
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Configure Nix
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    auto-optimise-store = true
  '';
  
  # Set up environment
  environment.systemPackages = with pkgs; [
    vim
    nano
    wget
    curl
    htop
    tree
    file
    unzip
    zip
    git
    jq
  ];
}