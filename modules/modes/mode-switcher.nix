{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-mode-switcher;
  
  modes = {
    starfleet = {
      name = "Starfleet Mode";
      description = "Standard Federation operations";
      theme = "starfleet";
      services = {
        monitoring = true;
        logging = true;
        backups = true;
        security = false;
        covert = false;
        aggressive = false;
      };
      colors = {
        primary = "#CC99CC";
        secondary = "#9999CC";
        accent = "#99CCCC";
        background = "#000033";
      };
    };
    
    section31 = {
      name = "Section 31 Mode";
      description = "Covert operations";
      theme = "section31";
      services = {
        monitoring = false;
        logging = false;
        backups = false;
        security = true;
        covert = true;
        aggressive = false;
      };
      colors = {
        primary = "#333333";
        secondary = "#1a1a1a";
        accent = "#666666";
        background = "#000000";
      };
    };
    
    borg = {
      name = "Borg Mode";
      description = "Assimilation protocols";
      theme = "borg";
      services = {
        monitoring = true;
        logging = true;
        backups = true;
        security = true;
        covert = true;
        aggressive = true;
      };
      colors = {
        primary = "#00FF00";
        secondary = "#008800";
        accent = "#004400";
        background = "#000000";
      };
    };
    
    terran = {
      name = "Terran Empire Mode";
      description = "Maximum aggression";
      theme = "terran";
      services = {
        monitoring = true;
        logging = false;
        backups = false;
        security = true;
        covert = false;
        aggressive = true;
      };
      colors = {
        primary = "#FFD700";
        secondary = "#8B4513";
        accent = "#FF6347";
        background = "#000000";
      };
    };
    
    holodeck = {
      name = "Holodeck Mode";
      description = "Simulation environment";
      theme = "holodeck";
      services = {
        monitoring = true;
        logging = true;
        backups = true;
        security = false;
        covert = false;
        aggressive = false;
      };
      colors = {
        primary = "#00BFFF";
        secondary = "#87CEEB";
        accent = "#B0E0E6";
        background = "#001133";
      };
    };
  };
  
in
{
  options.services.lcars-mode-switcher = {
    enable = mkEnableOption "LCARS operational mode switcher";
    
    defaultMode = mkOption {
      type = types.enum [ "starfleet" "section31" "borg" "terran" "holodeck" ];
      default = "starfleet";
      description = "Default operational mode";
    };
    
    enableHotSwitch = mkOption {
      type = types.bool;
      default = true;
      description = "Enable hot switching between modes";
    };
    
    requireAuthentication = mkOption {
      type = types.bool;
      default = true;
      description = "Require authentication for mode switching";
    };
  };

  config = mkIf cfg.enable {
    # Mode switcher service
    systemd.services.lcars-mode-switcher = {
      description = "LCARS Operational Mode Switcher";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.callPackage ./mode-switcher-service.nix { }}/bin/lcars-mode-switcher";
        Restart = "always";
        RestartSec = 2;
      };
      
      environment = {
        LCARS_DEFAULT_MODE = cfg.defaultMode;
        LCARS_HOT_SWITCH = if cfg.enableHotSwitch then "true" else "false";
        LCARS_REQUIRE_AUTH = if cfg.requireAuthentication then "true" else "false";
      };
    };
    
    # Mode-specific packages
    environment.systemPackages = with pkgs; [
      (callPackage ./mode-switcher-cli.nix { inherit modes; })
    ];
    
    # Mode configuration files
    environment.etc."lcars/modes.json" = {
      text = builtins.toJSON modes;
    };
    
    # Mode-specific services
    systemd.services.lcars-mode-monitor = {
      description = "LCARS Mode Monitor";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.callPackage ./mode-monitor.nix { }}/bin/mode-monitor";
        Restart = "always";
      };
    };
    
    # Create mode switcher desktop entry
    environment.etc."xdg/autostart/lcars-mode-switcher.desktop" = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=LCARS Mode Switcher
        Comment=Starfleet OS Mode Management
        Exec=${pkgs.callPackage ./mode-switcher-gui.nix { }}/bin/lcars-mode-gui
        Icon=lcars-mode
        Terminal=false
        Categories=System;
        StartupNotify=false
        X-GNOME-Autostart-enabled=true
      '';
    };
  };
}