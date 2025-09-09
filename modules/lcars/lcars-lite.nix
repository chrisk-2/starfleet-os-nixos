{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-lite;
in
{
  options.services.lcars-lite = {
    enable = mkEnableOption "Starfleet OS LCARS Lite Interface";
    
    mode = mkOption {
      type = types.enum [ "starfleet" "section31" "borg" "terran" "holodeck" ];
      default = "borg";
      description = "Operational mode for LCARS Lite interface";
    };
    
    resolution = mkOption {
      type = types.str;
      default = "1366x768";
      description = "Display resolution";
    };
    
    powerSaving = mkOption {
      type = types.bool;
      default = true;
      description = "Enable power saving features";
    };
    
    touchscreenSupport = mkOption {
      type = types.bool;
      default = true;
      description = "Enable touchscreen support";
    };
  };

  config = mkIf cfg.enable {
    # LCARS Lite display server
    services.xserver = {
      enable = true;
      
      displayManager = {
        sddm.enable = true;
        defaultSession = "lcars-lite";
      };
      
      desktopManager = {
        xterm.enable = false;
        
        session = [
          {
            name = "lcars-lite";
            start = ''
              ${pkgs.writeShellScript "start-lcars-lite" ''
                #!/bin/bash
                
                # Set LCARS mode
                export LCARS_MODE="${cfg.mode}"
                
                # Start LCARS Lite window manager
                ${pkgs.openbox}/bin/openbox &
                
                # Apply LCARS theme
                ${pkgs.feh}/bin/feh --bg-scale /etc/lcars/wallpapers/$LCARS_MODE.png
                
                # Start LCARS panel
                ${pkgs.tint2}/bin/tint2 -c /etc/lcars/tint2/$LCARS_MODE.conf &
                
                # Start LCARS dashboard
                ${pkgs.conky}/bin/conky -c /etc/lcars/conky/$LCARS_MODE.conf &
                
                # Start LCARS terminal
                ${pkgs.xterm}/bin/xterm -geometry 80x24+100+100 -fa "Liberation Mono" -fs 12 -bg "#000033" -fg "#99CCFF" -title "LCARS TERMINAL" &
                
                # Start LCARS control panel
                ${pkgs.writeShellScript "lcars-control-panel" ''
                  #!/bin/bash
                  
                  # Create LCARS control panel window
                  ${pkgs.yad}/bin/yad --form \
                    --title="LCARS Control Panel" \
                    --width=600 --height=400 \
                    --text="<span font='Liberation Sans 14'>LCARS Control Panel - ${cfg.mode} Mode</span>" \
                    --field="System Status:FBTN" "starfleet-status" \
                    --field="Network Status:FBTN" "starfleet-mesh-status" \
                    --field="Security Tools:FBTN" "starfleet-nmap --help" \
                    --field="Switch Mode:FBTN" "starfleet-mode-switch" \
                    --field="Power Options:FBTN" "systemctl poweroff" \
                    --button="Close:1"
                ''} &
                
                # Wait for window manager
                wait
              ''}
            '';
            manage = "window";
          }
        ];
      };
      
      # Input device configuration
      libinput = mkIf cfg.touchscreenSupport {
        enable = true;
        touchscreen.naturalScrolling = true;
      };
      
      # Display configuration
      displayManager.setupCommands = ''
        ${pkgs.xorg.xrandr}/bin/xrandr --output LVDS-1 --mode ${cfg.resolution} --primary
      '';
    };
    
    # Power management
    powerManagement = mkIf cfg.powerSaving {
      enable = true;
      powertop.enable = true;
      cpuFreqGovernor = "ondemand";
    };
    
    services.tlp = mkIf cfg.powerSaving {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };
    
    # LCARS theme configuration
    environment.etc = {
      # LCARS wallpapers
      "lcars/wallpapers/starfleet.png".source = ./themes/starfleet/wallpaper.png;
      "lcars/wallpapers/section31.png".source = ./themes/section31/wallpaper.png;
      "lcars/wallpapers/borg.png".source = ./themes/borg/wallpaper.png;
      "lcars/wallpapers/terran.png".source = ./themes/terran/wallpaper.png;
      "lcars/wallpapers/holodeck.png".source = ./themes/holodeck/wallpaper.png;
      
      # LCARS tint2 configurations
      "lcars/tint2/starfleet.conf".text = ''
        # Starfleet LCARS panel configuration
        panel_position = bottom center horizontal
        panel_size = 100% 40
        panel_margin = 0 0
        panel_padding = 0 0 0
        panel_background_id = 1
        wm_menu = 1
        panel_dock = 0
        panel_layer = top
        
        # Background
        rounded = 0
        border_width = 0
        background_color = #000033 100
        border_color = #CC99CC 100
        
        # Taskbar
        taskbar_mode = single_desktop
        taskbar_padding = 0 0 0
        taskbar_background_id = 0
        
        # Tasks
        task_icon = 1
        task_text = 1
        task_centered = 1
        task_maximum_size = 200 32
        task_padding = 10 5
        task_background_id = 2
        task_active_background_id = 3
        task_urgent_background_id = 4
        
        # Task Icons
        task_icon_asb = 100 0 0
        task_active_icon_asb = 100 0 0
        task_urgent_icon_asb = 100 0 0
        
        # Task Text
        task_text_color = #99CCCC 100
        task_active_text_color = #CC99CC 100
        task_urgent_text_color = #FFCC99 100
        
        # System Tray
        systray_padding = 10 5 5
        systray_background_id = 1
        systray_sort = ascending
        systray_icon_size = 16
        
        # Clock
        time1_format = %H:%M:%S
        time1_font = Liberation Sans Bold 12
        clock_font_color = #FFFFFF 100
        clock_padding = 10 0
        clock_background_id = 1
        
        # Tooltips
        tooltip = 1
        tooltip_padding = 10 5
        tooltip_show_timeout = 0.5
        tooltip_hide_timeout = 0.2
        tooltip_background_id = 5
        tooltip_font_color = #FFFFFF 100
        
        # Mouse
        mouse_middle = none
        mouse_right = close
        mouse_scroll_up = toggle
        mouse_scroll_down = iconify
        
        # Battery
        battery = 1
        battery_low_status = 20
        battery_low_cmd = notify-send "Battery Low"
        battery_hide = never
        bat1_font = Liberation Sans 10
        bat2_font = Liberation Sans 10
        battery_font_color = #FFFFFF 100
        battery_padding = 10 0
        battery_background_id = 1
        
        # End of config
      '';
      
      "lcars/tint2/borg.conf".text = ''
        # Borg LCARS panel configuration
        panel_position = bottom center horizontal
        panel_size = 100% 40
        panel_margin = 0 0
        panel_padding = 0 0 0
        panel_background_id = 1
        wm_menu = 1
        panel_dock = 0
        panel_layer = top
        
        # Background
        rounded = 0
        border_width = 0
        background_color = #000000 100
        border_color = #00FF00 100
        
        # Taskbar
        taskbar_mode = single_desktop
        taskbar_padding = 0 0 0
        taskbar_background_id = 0
        
        # Tasks
        task_icon = 1
        task_text = 1
        task_centered = 1
        task_maximum_size = 200 32
        task_padding = 10 5
        task_background_id = 2
        task_active_background_id = 3
        task_urgent_background_id = 4
        
        # Task Icons
        task_icon_asb = 100 0 0
        task_active_icon_asb = 100 0 0
        task_urgent_icon_asb = 100 0 0
        
        # Task Text
        task_text_color = #00FF00 100
        task_active_text_color = #00FF00 100
        task_urgent_text_color = #FFFF00 100
        
        # System Tray
        systray_padding = 10 5 5
        systray_background_id = 1
        systray_sort = ascending
        systray_icon_size = 16
        
        # Clock
        time1_format = %H:%M:%S
        time1_font = Liberation Mono Bold 12
        clock_font_color = #00FF00 100
        clock_padding = 10 0
        clock_background_id = 1
        
        # Tooltips
        tooltip = 1
        tooltip_padding = 10 5
        tooltip_show_timeout = 0.5
        tooltip_hide_timeout = 0.2
        tooltip_background_id = 5
        tooltip_font_color = #00FF00 100
        
        # Mouse
        mouse_middle = none
        mouse_right = close
        mouse_scroll_up = toggle
        mouse_scroll_down = iconify
        
        # Battery
        battery = 1
        battery_low_status = 20
        battery_low_cmd = notify-send "Battery Low"
        battery_hide = never
        bat1_font = Liberation Mono 10
        bat2_font = Liberation Mono 10
        battery_font_color = #00FF00 100
        battery_padding = 10 0
        battery_background_id = 1
        
        # End of config
      '';
      
      # LCARS conky configurations
      "lcars/conky/starfleet.conf".text = ''
        -- Starfleet LCARS dashboard configuration
        conky.config = {
          alignment = 'top_right',
          background = true,
          border_width = 0,
          cpu_avg_samples = 2,
          default_color = 'white',
          default_outline_color = 'white',
          default_shade_color = 'white',
          double_buffer = true,
          draw_borders = false,
          draw_graph_borders = true,
          draw_outline = false,
          draw_shades = false,
          use_xft = true,
          font = 'Liberation Sans:size=12',
          gap_x = 20,
          gap_y = 60,
          minimum_height = 5,
          minimum_width = 5,
          net_avg_samples = 2,
          no_buffers = true,
          out_to_console = false,
          out_to_stderr = false,
          extra_newline = false,
          own_window = true,
          own_window_class = 'Conky',
          own_window_type = 'desktop',
          own_window_transparent = false,
          own_window_argb_visual = true,
          own_window_argb_value = 200,
          own_window_colour = '#000033',
          stippled_borders = 0,
          update_interval = 1.0,
          uppercase = false,
          use_spacer = 'none',
          show_graph_scale = false,
          show_graph_range = false,
          color1 = '#CC99CC',
          color2 = '#9999CC',
          color3 = '#99CCCC',
        }
        
        conky.text = [[
        ${color1}STARFLEET OS - LCARS INTERFACE${color}
        ${color2}${hr}${color}
        
        ${color1}SYSTEM${color}
        ${color2}Hostname:${color} $nodename
        ${color2}Kernel:${color} $kernel
        ${color2}Uptime:${color} $uptime
        
        ${color1}CPU${color}
        ${color2}Usage:${color} $cpu% ${cpubar 4}
        ${color2}Frequency:${color} $freq_g GHz
        ${color2}Temperature:${color} ${acpitemp}°C
        ${color2}Load:${color} $loadavg
        
        ${color1}MEMORY${color}
        ${color2}RAM:${color} $mem/$memmax - $memperc% ${membar 4}
        ${color2}Swap:${color} $swap/$swapmax - $swapperc% ${swapbar 4}
        
        ${color1}STORAGE${color}
        ${color2}Root:${color} ${fs_used /}/${fs_size /} - ${fs_used_perc /}% ${fs_bar 4 /}
        
        ${color1}NETWORK${color}
        ${color2}Local IP:${color} ${addr wlan0}
        ${color2}Down:${color} ${downspeed wlan0} ${alignr}${color2}Up:${color} ${upspeed wlan0}
        ${downspeedgraph wlan0 25,120 99CCCC CC99CC} ${alignr}${upspeedgraph wlan0 25,120 99CCCC CC99CC}
        ${color2}Total Down:${color} ${totaldown wlan0} ${alignr}${color2}Total Up:${color} ${totalup wlan0}
        
        ${color1}PROCESSES${color}
        ${color2}Total:${color} $processes  ${color2}Running:${color} $running_processes
        ${color2}Name              PID    CPU%   MEM%${color}
        ${top name 1} ${top pid 1} ${top cpu 1} ${top mem 1}
        ${top name 2} ${top pid 2} ${top cpu 2} ${top mem 2}
        ${top name 3} ${top pid 3} ${top cpu 3} ${top mem 3}
        ${top name 4} ${top pid 4} ${top cpu 4} ${top mem 4}
        
        ${color1}STARDATE${color} ${color3}${time %Y.%j}${color}
        ]]
      '';
      
      "lcars/conky/borg.conf".text = ''
        -- Borg LCARS dashboard configuration
        conky.config = {
          alignment = 'top_right',
          background = true,
          border_width = 0,
          cpu_avg_samples = 2,
          default_color = '#00FF00',
          default_outline_color = '#00FF00',
          default_shade_color = '#00FF00',
          double_buffer = true,
          draw_borders = false,
          draw_graph_borders = true,
          draw_outline = false,
          draw_shades = false,
          use_xft = true,
          font = 'Liberation Mono:size=12',
          gap_x = 20,
          gap_y = 60,
          minimum_height = 5,
          minimum_width = 5,
          net_avg_samples = 2,
          no_buffers = true,
          out_to_console = false,
          out_to_stderr = false,
          extra_newline = false,
          own_window = true,
          own_window_class = 'Conky',
          own_window_type = 'desktop',
          own_window_transparent = false,
          own_window_argb_visual = true,
          own_window_argb_value = 200,
          own_window_colour = '#000000',
          stippled_borders = 0,
          update_interval = 1.0,
          uppercase = false,
          use_spacer = 'none',
          show_graph_scale = false,
          show_graph_range = false,
          color1 = '#00FF00',
          color2 = '#008800',
          color3 = '#004400',
        }
        
        conky.text = [[
        ${color1}BORG COLLECTIVE - DRONE INTERFACE${color}
        ${color2}${hr}${color}
        
        ${color1}SYSTEM${color}
        ${color2}Designation:${color} $nodename
        ${color2}Kernel:${color} $kernel
        ${color2}Uptime:${color} $uptime
        
        ${color1}PROCESSING${color}
        ${color2}Usage:${color} $cpu% ${cpubar 4}
        ${color2}Frequency:${color} $freq_g GHz
        ${color2}Temperature:${color} ${acpitemp}°C
        ${color2}Load:${color} $loadavg
        
        ${color1}MEMORY BANKS${color}
        ${color2}Primary:${color} $mem/$memmax - $memperc% ${membar 4}
        ${color2}Secondary:${color} $swap/$swapmax - $swapperc% ${swapbar 4}
        
        ${color1}STORAGE NODES${color}
        ${color2}Main:${color} ${fs_used /}/${fs_size /} - ${fs_used_perc /}% ${fs_bar 4 /}
        
        ${color1}COMMUNICATION${color}
        ${color2}Link:${color} ${addr wlan0}
        ${color2}Receiving:${color} ${downspeed wlan0} ${alignr}${color2}Transmitting:${color} ${upspeed wlan0}
        ${downspeedgraph wlan0 25,120 004400 00FF00} ${alignr}${upspeedgraph wlan0 25,120 004400 00FF00}
        ${color2}Total Received:${color} ${totaldown wlan0} ${alignr}${color2}Total Sent:${color} ${totalup wlan0}
        
        ${color1}ACTIVE PROCESSES${color}
        ${color2}Total:${color} $processes  ${color2}Running:${color} $running_processes
        ${color2}Designation       PID    CPU%   MEM%${color}
        ${top name 1} ${top pid 1} ${top cpu 1} ${top mem 1}
        ${top name 2} ${top pid 2} ${top cpu 2} ${top mem 2}
        ${top name 3} ${top pid 3} ${top cpu 3} ${top mem 3}
        ${top name 4} ${top pid 4} ${top cpu 4} ${top mem 4}
        
        ${color1}ASSIMILATION PROGRESS${color} ${color3}${time %Y.%j.%H%M%S}${color}
        ]]
      '';
    };
    
    # LCARS Lite tools
    environment.systemPackages = with pkgs; [
      # Window manager and desktop
      openbox
      tint2
      feh
      conky
      yad
      
      # Terminal and utilities
      xterm
      rxvt-unicode
      
      # LCARS tools
      (writeScriptBin "lcars-lite-status" ''
        #!/bin/bash
        echo "Starfleet OS LCARS Lite Status"
        echo "============================"
        
        echo "Mode: ${cfg.mode}"
        echo "Resolution: ${cfg.resolution}"
        echo "Power saving: ${if cfg.powerSaving then "Enabled" else "Disabled"}"
        echo "Touchscreen support: ${if cfg.touchscreenSupport then "Enabled" else "Disabled"}"
        
        echo ""
        echo "Display server:"
        systemctl status display-manager
        
        echo ""
        echo "Power management:"
        if ${toString cfg.powerSaving}; then
          systemctl status tlp
        else
          echo "Power saving disabled"
        fi
        
        echo ""
        echo "System resources:"
        free -h
        df -h /
      '')
      
      (writeScriptBin "lcars-lite-switch-mode" ''
        #!/bin/bash
        if [ $# -lt 1 ]; then
          echo "Usage: lcars-lite-switch-mode <mode>"
          echo "Available modes: starfleet, section31, borg, terran, holodeck"
          exit 1
        fi
        
        MODE=$1
        
        case "$MODE" in
          "starfleet"|"section31"|"borg"|"terran"|"holodeck")
            echo "Switching to $MODE mode..."
            sed -i "s/mode = &quot;.*&quot;/mode = &quot;$MODE&quot;/" /etc/nixos/configuration.nix
            nixos-rebuild switch
            ;;
          *)
            echo "Invalid mode: $MODE"
            echo "Available modes: starfleet, section31, borg, terran, holodeck"
            exit 1
            ;;
        esac
      '')
    ];
  };
}