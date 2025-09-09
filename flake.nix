{
  description = "Starfleet OS - Pure LCARS NixOS Distribution";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    
    # LCARS-specific inputs
    hyprland.url = "github:hyprwm/Hyprland";
    waybar.url = "github:Alexays/Waybar";
    # Removing wlogout as a direct input since it doesn't have a flake.nix
    
    # Security tools
    nix-security.url = "github:NixOS/nixpkgs/master";
    
    # Home-manager for user configurations
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, hyprland, waybar, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      # LCARS color schemes
      lcarsColors = {
        starfleet = {
          primary = "#CC99CC";
          secondary = "#9999CC";
          accent = "#99CCCC";
          background = "#000033";
          text = "#FFFFFF";
          warning = "#FFCC99";
          danger = "#CC6666";
        };
        
        section31 = {
          primary = "#333333";
          secondary = "#1a1a1a";
          accent = "#666666";
          background = "#000000";
          text = "#cccccc";
          warning = "#990000";
          danger = "#ff0000";
        };
        
        borg = {
          primary = "#00FF00";
          secondary = "#008800";
          accent = "#004400";
          background = "#000000";
          text = "#00FF00";
          warning = "#FFFF00";
          danger = "#FF0000";
        };
        
        terran = {
          primary = "#FFD700";
          secondary = "#8B4513";
          accent = "#FF6347";
          background = "#000000";
          text = "#FFD700";
          warning = "#FF4500";
          danger = "#DC143C";
        };
      };
      
      # Node role configurations
      nodeRoles = {
        bridge = {
          hostname = "uss-enterprise-bridge";
          description = "Command Console - Full LCARS visuals";
          services = [ "lcars-display" "fleet-health" "ai-helpers" "alarm-system" ];
          interfaces = [ "lcars-full" "command-control" "camera-feeds" ];
        };
        
        drone-a = {
          hostname = "borg-drone-alpha";
          description = "Hive Backbone - Core monitoring";
          services = [ "monitoring" "logging" "backup-repo" "bloodhound-neo4j" ];
          interfaces = [ "mesh-hub" "service-discovery" ];
        };
        
        drone-b = {
          hostname = "borg-drone-beta";
          description = "Auxiliary Node - Service redundancy";
          services = [ "redundancy" "storage" "sandbox" "failover" ];
          interfaces = [ "mirror-services" ];
        };
        
        edge-pi = {
          hostname = "edge-sensor-drone";
          description = "Lightweight Sensor Drone";
          services = [ "onvif-discovery" "mqtt-relay" "heartbeat" "watchdog" ];
          interfaces = [ "sensor-interface" "relay-services" ];
        };
        
        portable = {
          hostname = "mobile-assimilation-unit";
          description = "Expansion Node - Mobile hive presence";
          services = [ "lcars-lite" "tunnel-service" "assimilation-tools" ];
          interfaces = [ "mobile-interface" "usb-assimilation" ];
        };
      };
      
    in
    {
      # NixOS configurations for each node type
      nixosConfigurations = {
        # Bridge configuration - Full LCARS interface
        bridge = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/bridge/configuration.nix
            ./modules/lcars/display-server.nix
            ./modules/lcars/compositor.nix
            ./modules/security/pentest-suite.nix
            ./modules/fleet/health-monitoring.nix
            ./modules/fleet/camera-ops.nix
            ./modules/fleet/ai-helpers.nix
            ./modules/modes/mode-switcher.nix
          ];
        };
        
        # Drone-A configuration - Hive backbone
        drone-a = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/drone-a/configuration.nix
            ./modules/hive/monitoring-services.nix
            ./modules/hive/logging-services.nix
            ./modules/hive/backup-repo.nix
            ./modules/security/bloodhound-neo4j.nix
            ./modules/network/wireguard-mesh.nix
          ];
        };
        
        # Drone-B configuration - Auxiliary node
        drone-b = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/drone-b/configuration.nix
            ./modules/hive/redundancy-services.nix
            ./modules/hive/storage-extension.nix
            ./modules/hive/sandbox-workloads.nix
            ./modules/network/failover-system.nix
          ];
        };
        
        # Edge-PI configuration - Raspberry Pi
        edge-pi = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./modules/edge-pi/configuration.nix
            ./modules/sensors/onvif-discovery.nix
            ./modules/sensors/mqtt-relay.nix
            ./modules/system/watchdog.nix
            ./modules/network/heartbeat.nix
          ];
        };
        
        # Portable configuration - Laptop/Tablet/USB
        portable = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/portable/configuration.nix
            ./modules/lcars/lcars-lite.nix
            ./modules/network/tunnel-service.nix
            ./modules/assimilation/usb-tools.nix
            ./modules/system/ventoy-recovery.nix
          ];
        };
      };
      
      # Home-manager configurations for user environments
      homeConfigurations = {
        starfleet-user = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home/starfleet/lcars-environment.nix
            ./home/starfleet/desktop-applications.nix
            ./home/starfleet/development-tools.nix
          ];
        };
      };
      
      # Development shells
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixos-generators
          nixos-rebuild
          qemu
          docker
          git
          curl
          jq
          yq
          age
          sops
        ];
        
        shellHook = ''
          echo "Welcome to Starfleet OS Development Environment"
          echo "Current LCARS Mode: $LCARS_MODE"
          echo "Available modes: starfleet, section31, borg, terran, holodeck"
          export LCARS_DEV=1
        '';
      };
      
      # Packages for the system
      packages.${system} = {
        lcars-desktop = pkgs.callPackage ./pkgs/lcars-desktop { inherit lcarsColors; };
        lcars-compositor = pkgs.callPackage ./pkgs/lcars-compositor { inherit lcarsColors; };
        starfleet-cli = pkgs.callPackage ./pkgs/starfleet-cli { inherit nodeRoles; };
        assimilation-tools = pkgs.callPackage ./pkgs/assimilation-tools { };
        fleet-health-monitor = pkgs.callPackage ./pkgs/fleet-health-monitor { };
        # Add wlogout as a direct package instead of a flake input
        wlogout = pkgs.wlogout;
      };
      
      # ISO generation
      nixosModules.iso = { config, pkgs, ... }: {
        imports = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/iso-image.nix"
        ];
        
        isoImage.isoBaseName = "starfleet-os";
        isoImage.volumeID = "STARFLEET_OS";
        isoImage.contents = [
          { source = ./README.md;
            target = "/README.md";
          }
        ];
      };
    };
}