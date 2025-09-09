{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-compositor;
in
{
  options.services.lcars-compositor = {
    enable = mkEnableOption "LCARS window compositor";
    
    mode = mkOption {
      type = types.enum [ "starfleet" "section31" "borg" "terran" "holodeck" ];
      default = "starfleet";
      description = "Operational mode for LCARS compositor";
    };
    
    animations = mkOption {
      type = types.bool;
      default = true;
      description = "Enable LCARS animations";
    };
    
    effects = mkOption {
      type = types.bool;
      default = true;
      description = "Enable LCARS visual effects";
    };
    
    soundEffects = mkOption {
      type = types.bool;
      default = true;
      description = "Enable LCARS sound effects";
    };
  };

  config = mkIf cfg.enable {
    # LCARS compositor configuration
    environment.systemPackages = with pkgs; [
      lcars-compositor
    ];
    
    # Wayland configuration
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };
    
    # LCARS compositor service
    systemd.user.services.lcars-compositor = {
      description = "LCARS Window Compositor";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.lcars-compositor}/bin/lcars-compositor --mode ${cfg.mode} ${optionalString (!cfg.animations) "--no-animations"} ${optionalString (!cfg.effects) "--no-effects"} ${optionalString (!cfg.soundEffects) "--no-sound"}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      
      environment = {
        LCARS_MODE = cfg.mode;
        LCARS_ANIMATIONS = if cfg.animations then "1" else "0";
        LCARS_EFFECTS = if cfg.effects then "1" else "0";
        LCARS_SOUND = if cfg.soundEffects then "1" else "0";
      };
    };
    
    # LCARS session
    services.xserver.displayManager.sessionPackages = [ pkgs.lcars-session ];
    
    # LCARS sound effects
    sound.enable = true;
    hardware.pulseaudio.enable = true;
    
    # LCARS theme for GTK applications
    environment.etc."xdg/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-theme-name=LCARS-${cfg.mode}
      gtk-icon-theme-name=LCARS-${cfg.mode}
      gtk-font-name=LCARS 11
      gtk-cursor-theme-name=LCARS-${cfg.mode}
      gtk-cursor-theme-size=24
    '';
    
    # LCARS theme for Qt applications
    environment.variables = {
      QT_QPA_PLATFORMTHEME = "qt5ct";
      QT_STYLE_OVERRIDE = "kvantum";
    };
    
    # LCARS theme for Kvantum
    environment.etc."xdg/Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=LCARS-${cfg.mode}
    '';
  };
}