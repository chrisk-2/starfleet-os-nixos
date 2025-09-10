# LCARS Boot Sequence Implementation
# Starfleet OS Boot Process Design

## Overview

The LCARS boot sequence provides a visually consistent Star Trek-inspired experience from power-on to login. This document outlines the implementation plan for creating a complete LCARS-themed boot process for Starfleet OS.

## Design Principles

1. **Visual Consistency**: Maintain LCARS design language throughout the entire boot process
2. **Informative Feedback**: Provide clear status information during boot
3. **Mode-Specific Theming**: Apply different visual styles based on operational mode
4. **Smooth Transitions**: Create seamless transitions between boot stages
5. **Hardware Compatibility**: Ensure compatibility with various hardware configurations

## Implementation Components

### 1. UEFI Boot Splash

#### Requirements
- Replace default GRUB/systemd-boot splash with LCARS-themed graphic
- Create mode-specific boot splash variants
- Implement hardware detection for resolution selection

#### Implementation
```nix
# In modules/lcars/boot-splash.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.lcars-splash;
  modeColors = import ../modes/mode-colors.nix;
  currentMode = config.services.lcars-display.mode or "starfleet";
  splashTheme = modeColors.${currentMode} or modeColors.starfleet;
in {
  options.boot.lcars-splash = {
    enable = mkEnableOption "LCARS boot splash screen";
    
    resolution = mkOption {
      type = types.str;
      default = "auto";
      description = "Resolution for boot splash (auto, 1080p, 4k)";
    };
    
    animation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable boot animation";
    };
  };
  
  config = mkIf cfg.enable {
    boot.loader.systemd-boot.configurationLimit = 10;
    boot.loader.systemd-boot.consoleMode = "auto";
    boot.loader.systemd-boot.memtest86.enable = true;
    
    boot.loader.systemd-boot.extraFiles = {
      "EFI/systemd/starfleet-splash.bmp" = 
        "${pkgs.lcars-boot-assets}/splash/${currentMode}-${cfg.resolution}.bmp";
    };
    
    boot.loader.systemd-boot.extraEntries = {
      "starfleet-boot.conf" = ''
        title Starfleet OS (${currentMode} mode)
        linux /EFI/nixos/kernel
        initrd /EFI/nixos/initrd
        options splash quiet plymouth.enable=1 plymouth.theme=lcars-${currentMode}
      '';
    };
    
    boot.plymouth = {
      enable = true;
      themeDir = "${pkgs.lcars-plymouth-theme}/share/plymouth/themes";
      theme = "lcars-${currentMode}";
    };
  };
}
```

### 2. Plymouth Theme Integration

#### Requirements
- Create LCARS-themed Plymouth themes for each operational mode
- Design boot progress indicators in LCARS style
- Implement smooth transitions between boot stages

#### Implementation
```bash
# Directory structure for Plymouth themes
pkgs/
  lcars-plymouth-theme/
    default.nix
    themes/
      lcars-starfleet/
        lcars-starfleet.plymouth
        progress_bar.png
        background.png
        logo.png
        animation/
          frame01.png
          frame02.png
          # ... more frames
      lcars-section31/
        # Similar structure
      lcars-borg/
        # Similar structure
      lcars-terran/
        # Similar structure
      lcars-holodeck/
        # Similar structure
```

```nix
# In pkgs/lcars-plymouth-theme/default.nix
{ lib, stdenv, plymouth, lcarsColors }:

stdenv.mkDerivation {
  pname = "lcars-plymouth-theme";
  version = "1.0.0";
  
  src = ./themes;
  
  buildInputs = [ plymouth ];
  
  installPhase = ''
    mkdir -p $out/share/plymouth/themes
    
    # Install all LCARS themes
    cp -r lcars-starfleet $out/share/plymouth/themes/
    cp -r lcars-section31 $out/share/plymouth/themes/
    cp -r lcars-borg $out/share/plymouth/themes/
    cp -r lcars-terran $out/share/plymouth/themes/
    cp -r lcars-holodeck $out/share/plymouth/themes/
  '';
  
  meta = with lib; {
    description = "LCARS-themed Plymouth themes for Starfleet OS";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
```

### 3. Boot Progress Indicators

#### Requirements
- Create LCARS-style progress bar for boot process
- Display system initialization status
- Show hardware detection progress
- Indicate service startup status

#### Implementation
Create a custom Plymouth script for LCARS progress indicators:

```
# Example Plymouth script for LCARS progress bar
Window.SetBackgroundTopColor(0, 0, 0.2);
Window.SetBackgroundBottomColor(0, 0, 0.2);

logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetPosition(Window.GetWidth() / 2 - logo.image.GetWidth() / 2, Window.GetHeight() / 2 - logo.image.GetHeight() / 2, 10000);

progress_box.image = Image("progress_bar_background.png");
progress_box.sprite = Sprite(progress_box.image);
progress_box.sprite.SetPosition(Window.GetWidth() / 2 - progress_box.image.GetWidth() / 2, Window.GetHeight() * 0.75 - progress_box.image.GetHeight() / 2, 0);

progress_bar.original_image = Image("progress_bar.png");
progress_bar.sprite = Sprite();
progress_bar.sprite.SetPosition(Window.GetWidth() / 2 - progress_box.image.GetWidth() / 2, Window.GetHeight() * 0.75 - progress_box.image.GetHeight() / 2, 1);

status_text = Text(Window.GetWidth() / 2, Window.GetHeight() * 0.75 + 26);
status_text.SetText("Initializing LCARS systems...");
status_text.SetColor(1, 0.8, 0.2, 1);

fun refresh_callback() {
  progress = Plymouth.GetBootProgress();
  if (progress < 0.1) {
    status_text.SetText("Initializing LCARS core systems...");
  } else if (progress < 0.3) {
    status_text.SetText("Detecting hardware components...");
  } else if (progress < 0.5) {
    status_text.SetText("Starting system services...");
  } else if (progress < 0.7) {
    status_text.SetText("Initializing LCARS interface...");
  } else if (progress < 0.9) {
    status_text.SetText("Establishing fleet connections...");
  } else {
    status_text.SetText("Preparing command console...");
  }
  
  width = progress_bar.original_image.GetWidth() * progress;
  progress_bar.image = progress_bar.original_image.Scale(width, progress_bar.original_image.GetHeight());
  progress_bar.sprite.SetImage(progress_bar.image);
}

Plymouth.SetRefreshFunction(refresh_callback);
```

### 4. systemd Integration

#### Requirements
- Integrate LCARS boot sequence with systemd
- Create custom systemd units for LCARS initialization
- Implement boot status reporting

#### Implementation
```nix
# In modules/lcars/boot-sequence.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-boot-sequence;
in {
  options.services.lcars-boot-sequence = {
    enable = mkEnableOption "LCARS boot sequence";
    
    bootSplash = mkOption {
      type = types.bool;
      default = true;
      description = "Enable LCARS boot splash";
    };
    
    bootAnimation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable LCARS boot animation";
    };
    
    bootSound = mkOption {
      type = types.bool;
      default = true;
      description = "Enable LCARS boot sound";
    };
  };
  
  config = mkIf cfg.enable {
    # Enable LCARS boot splash
    boot.lcars-splash = {
      enable = cfg.bootSplash;
      animation = cfg.bootAnimation;
    };
    
    # Create systemd service for LCARS boot sequence
    systemd.services.lcars-boot-sequence = {
      description = "LCARS Boot Sequence";
      wantedBy = [ "multi-user.target" ];
      before = [ "display-manager.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.lcars-boot-sequence}/bin/lcars-boot-sequence";
        RemainAfterExit = true;
      };
      
      environment = {
        LCARS_MODE = config.services.lcars-display.mode or "starfleet";
        LCARS_BOOT_SOUND = lib.boolToString cfg.bootSound;
      };
    };
    
    # Add boot sound if enabled
    systemd.services.lcars-boot-sound = mkIf cfg.bootSound {
      description = "LCARS Boot Sound";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.lcars-boot-sequence}/bin/lcars-boot-sound";
      };
      
      environment = {
        LCARS_MODE = config.services.lcars-display.mode or "starfleet";
      };
    };
    
    # Add required packages
    environment.systemPackages = with pkgs; [
      lcars-boot-sequence
      lcars-plymouth-theme
    ];
  };
}
```

### 5. Boot Animation Implementation

#### Requirements
- Create mode-specific boot animations
- Design smooth transitions between boot stages
- Implement hardware-accelerated animations

#### Implementation
Create a C/C++ program for the boot animation:

```c
// src/boot-animation.c
#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_FRAMES 60
#define FRAME_DELAY 33 // ~30fps

typedef struct {
    char* mode;
    SDL_Color primary;
    SDL_Color secondary;
    SDL_Color accent;
    SDL_Color background;
} LcarsTheme;

LcarsTheme themes[] = {
    {"starfleet", {204, 153, 204, 255}, {153, 153, 204, 255}, {153, 204, 204, 255}, {0, 0, 51, 255}},
    {"section31", {51, 51, 51, 255}, {26, 26, 26, 255}, {102, 102, 102, 255}, {0, 0, 0, 255}},
    {"borg", {0, 255, 0, 255}, {0, 136, 0, 255}, {0, 68, 0, 255}, {0, 0, 0, 255}},
    {"terran", {255, 215, 0, 255}, {139, 69, 19, 255}, {255, 99, 71, 255}, {0, 0, 0, 255}},
    {"holodeck", {255, 255, 255, 255}, {200, 200, 200, 255}, {100, 100, 100, 255}, {0, 0, 0, 255}}
};

int main(int argc, char* argv[]) {
    char* mode = getenv("LCARS_MODE");
    if (!mode) mode = "starfleet";
    
    // Initialize SDL
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        fprintf(stderr, "SDL could not initialize! SDL_Error: %s\n", SDL_GetError());
        return 1;
    }
    
    // Get display info
    SDL_DisplayMode dm;
    if (SDL_GetCurrentDisplayMode(0, &dm) != 0) {
        fprintf(stderr, "SDL could not get display mode! SDL_Error: %s\n", SDL_GetError());
        return 1;
    }
    
    // Create window
    SDL_Window* window = SDL_CreateWindow("LCARS Boot Animation", 
                                         SDL_WINDOWPOS_UNDEFINED, 
                                         SDL_WINDOWPOS_UNDEFINED, 
                                         dm.w, dm.h, 
                                         SDL_WINDOW_SHOWN | SDL_WINDOW_FULLSCREEN);
    
    if (!window) {
        fprintf(stderr, "Window could not be created! SDL_Error: %s\n", SDL_GetError());
        return 1;
    }
    
    // Create renderer
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) {
        fprintf(stderr, "Renderer could not be created! SDL_Error: %s\n", SDL_GetError());
        return 1;
    }
    
    // Load animation frames
    char path[256];
    SDL_Texture* frames[MAX_FRAMES];
    int frameCount = 0;
    
    for (int i = 0; i < MAX_FRAMES; i++) {
        sprintf(path, "/usr/share/lcars-boot/animations/%s/frame%02d.png", mode, i + 1);
        SDL_Surface* surface = IMG_Load(path);
        if (!surface) break;
        
        frames[frameCount] = SDL_CreateTextureFromSurface(renderer, surface);
        SDL_FreeSurface(surface);
        frameCount++;
    }
    
    if (frameCount == 0) {
        fprintf(stderr, "No animation frames found for mode: %s\n", mode);
        return 1;
    }
    
    // Play animation
    SDL_Event e;
    int quit = 0;
    int currentFrame = 0;
    
    while (!quit) {
        while (SDL_PollEvent(&e) != 0) {
            if (e.type == SDL_QUIT) {
                quit = 1;
            } else if (e.type == SDL_KEYDOWN) {
                quit = 1;
            }
        }
        
        // Clear screen
        LcarsTheme* theme = NULL;
        for (int i = 0; i < sizeof(themes) / sizeof(LcarsTheme); i++) {
            if (strcmp(themes[i].mode, mode) == 0) {
                theme = &themes[i];
                break;
            }
        }
        
        if (!theme) theme = &themes[0]; // Default to starfleet
        
        SDL_SetRenderDrawColor(renderer, 
                              theme->background.r, 
                              theme->background.g, 
                              theme->background.b, 
                              theme->background.a);
        SDL_RenderClear(renderer);
        
        // Render current frame
        SDL_RenderCopy(renderer, frames[currentFrame], NULL, NULL);
        SDL_RenderPresent(renderer);
        
        // Next frame
        currentFrame = (currentFrame + 1) % frameCount;
        
        // Delay
        SDL_Delay(FRAME_DELAY);
    }
    
    // Cleanup
    for (int i = 0; i < frameCount; i++) {
        SDL_DestroyTexture(frames[i]);
    }
    
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    
    return 0;
}
```

### 6. Boot Sound Implementation

#### Requirements
- Create mode-specific boot sounds
- Implement sound playback during boot
- Ensure compatibility with different audio hardware

#### Implementation
```nix
# In pkgs/lcars-boot-sequence/default.nix
{ lib, stdenv, fetchFromGitHub, SDL2, SDL2_image, SDL2_mixer }:

stdenv.mkDerivation {
  pname = "lcars-boot-sequence";
  version = "1.0.0";
  
  src = ./src;
  
  buildInputs = [ SDL2 SDL2_image SDL2_mixer ];
  
  buildPhase = ''
    gcc -o lcars-boot-sequence boot-animation.c -lSDL2 -lSDL2_image
    gcc -o lcars-boot-sound boot-sound.c -lSDL2 -lSDL2_mixer
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp lcars-boot-sequence $out/bin/
    cp lcars-boot-sound $out/bin/
    
    mkdir -p $out/share/lcars-boot/animations
    mkdir -p $out/share/lcars-boot/sounds
    
    cp -r animations/* $out/share/lcars-boot/animations/
    cp -r sounds/* $out/share/lcars-boot/sounds/
  '';
  
  meta = with lib; {
    description = "LCARS boot sequence for Starfleet OS";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
```

## Testing Plan

### 1. Virtual Machine Testing
- Test boot sequence in QEMU/VirtualBox
- Verify all animations and sounds work correctly
- Test with different screen resolutions
- Test with different hardware configurations

### 2. Hardware Testing
- Test on OptiPlex bridge hardware
- Test on laptop/portable hardware
- Test on Raspberry Pi (edge-pi)
- Verify compatibility with different GPUs

### 3. Performance Testing
- Measure boot time with and without animations
- Test on low-end hardware
- Optimize for performance

## Integration with Existing Components

### 1. Mode Switcher Integration
```nix
# In modules/modes/mode-switcher.nix
{ config, lib, pkgs, ... }:

# Add to existing mode-switcher.nix
{
  config = mkIf cfg.enable {
    # Existing configuration...
    
    # Add boot sequence configuration
    services.lcars-boot-sequence = {
      enable = true;
      bootSplash = true;
      bootAnimation = true;
      bootSound = true;
    };
    
    # Update boot splash when mode changes
    system.activationScripts.updateLcarsBootSplash = ''
      # Update Plymouth theme based on current mode
      if [ -f /etc/plymouth/plymouthd.conf ]; then
        sed -i 's/Theme=.*/Theme=lcars-${cfg.currentMode}/' /etc/plymouth/plymouthd.conf
      fi
      
      # Rebuild initrd to include new Plymouth theme
      if [ -x /run/current-system/bin/switch-to-configuration ]; then
        /run/current-system/bin/switch-to-configuration boot
      fi
    '';
  };
}
```

### 2. Display Server Integration
```nix
# In modules/lcars/display-server.nix
{ config, lib, pkgs, ... }:

# Add to existing display-server.nix
{
  config = mkIf cfg.enable {
    # Existing configuration...
    
    # Add boot sequence integration
    services.lcars-display.bootTransition = mkIf config.services.lcars-boot-sequence.enable {
      enable = true;
      duration = 1500; # milliseconds
    };
    
    # Add systemd target for LCARS boot completion
    systemd.targets.lcars-boot-complete = {
      description = "LCARS Boot Sequence Complete";
      requires = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      wantedBy = [ "graphical.target" ];
    };
    
    # Add transition from boot animation to display server
    systemd.services.lcars-display.wants = [ "lcars-boot-complete.target" ];
  };
}
```

## Deliverables

1. **Plymouth Themes**: LCARS-themed Plymouth themes for all operational modes
2. **Boot Animation**: Custom boot animation program with mode-specific animations
3. **Boot Sound**: Mode-specific boot sounds
4. **systemd Integration**: Complete integration with systemd boot process
5. **NixOS Modules**: NixOS modules for LCARS boot sequence configuration
6. **Documentation**: Complete documentation for the LCARS boot sequence

## Timeline

1. **Week 1**: Design and implement Plymouth themes
2. **Week 2**: Create boot animations and sounds
3. **Week 3**: Implement systemd integration
4. **Week 4**: Testing and optimization

## Conclusion

The LCARS boot sequence implementation will provide a visually consistent and immersive experience from power-on to login. By following the Star Trek LCARS design language throughout the boot process, users will be fully immersed in the Starfleet OS experience from the moment they power on their system.