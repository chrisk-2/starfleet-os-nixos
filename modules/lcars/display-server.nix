{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-display;
in
{
  options.services.lcars-display = {
    enable = mkEnableOption "LCARS display server";
    
    mode = mkOption {
      type = types.enum [ "starfleet" "section31" "borg" "terran" "holodeck" ];
      default = "starfleet";
      description = "Operational mode for LCARS interface";
    };
    
    resolution = mkOption {
      type = types.str;
      default = "1920x1080";
      description = "Display resolution";
    };
    
    refreshRate = mkOption {
      type = types.int;
      default = 60;
      description = "Display refresh rate";
    };
    
    theme = mkOption {
      type = types.attrs;
      default = {
        primary = "#CC99CC";
        secondary = "#9999CC";
        accent = "#99CCCC";
        background = "#000033";
        text = "#FFFFFF";
        warning = "#FFCC99";
        danger = "#CC6666";
      };
      description = "LCARS color scheme";
    };
  };

  config = mkIf cfg.enable {
    # Custom LCARS display server
    systemd.services.lcars-display = {
      description = "LCARS Display Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udevd.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.lcars-desktop}/bin/lcars-display --mode ${cfg.mode} --resolution ${cfg.resolution} --refresh ${toString cfg.refreshRate}";
        Restart = "always";
        RestartSec = 2;
      };
      
      environment = {
        LCARS_MODE = cfg.mode;
        LCARS_THEME = builtins.toJSON cfg.theme;
      };
    };
    
    # LCARS compositor
    systemd.services.lcars-compositor = {
      description = "LCARS Window Compositor";
      wantedBy = [ "multi-user.target" ];
      after = [ "lcars-display.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.lcars-compositor}/bin/lcars-compositor";
        Restart = "always";
      };
    };
    
    # Create starfleet user
    users.users.starfleet = {
      isNormalUser = true;
      description = "Starfleet OS User";
      extraGroups = [ "video" "audio" "input" "wheel" ];
    };
    
    # Install LCARS fonts
    fonts.packages = with pkgs; [
      liberation_ttf
      noto-fonts
      dejavu_fonts
      (callPackage ./lcars-fonts.nix { })
    ];
    
    # Display configuration
    services.xserver = {
      enable = false; # Disable X11 for pure LCARS
    };
    
    # Wayland configuration for LCARS
    programs.hyprland.enable = true;
    
    # Graphics drivers
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
  };
}