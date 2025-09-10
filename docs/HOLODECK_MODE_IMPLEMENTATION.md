# Holodeck Mode Implementation
# Starfleet OS Simulation Environment

## Overview

The Holodeck mode provides a secure, isolated simulation environment for testing, training, and experimentation within Starfleet OS. This document outlines the implementation plan for creating a complete Holodeck mode that follows the Star Trek concept of a programmable environment for simulations.

## Design Principles

1. **Isolation**: Create a fully isolated environment for safe experimentation
2. **Simulation**: Support various simulation scenarios and templates
3. **Containment**: Ensure activities in Holodeck mode cannot affect the main system
4. **Flexibility**: Allow users to create and modify simulation environments
5. **Visual Consistency**: Maintain LCARS design language with Holodeck-specific elements

## Implementation Components

### 1. Holodeck Mode Switcher Integration

#### Requirements
- Integrate with the existing mode switcher system
- Create Holodeck-specific LCARS theme
- Implement transition animations between modes
- Provide Holodeck-specific system configurations

#### Implementation
```nix
# In modules/modes/holodeck-mode.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.holodeck-mode;
in {
  options.services.holodeck-mode = {
    enable = mkEnableOption "Holodeck simulation mode";
    
    defaultTemplate = mkOption {
      type = types.str;
      default = "starship-bridge";
      description = "Default simulation template";
    };
    
    securityLevel = mkOption {
      type = types.enum [ "low" "medium" "high" "maximum" ];
      default = "high";
      description = "Security level for simulation containment";
    };
    
    persistSimulations = mkOption {
      type = types.bool;
      default = true;
      description = "Persist simulations between sessions";
    };
    
    simulationDirectory = mkOption {
      type = types.str;
      default = "/var/lib/holodeck/simulations";
      description = "Directory to store simulation data";
    };
  };
  
  config = mkIf cfg.enable {
    # Add Holodeck mode to mode switcher
    services.mode-switcher.modes = {
      holodeck = {
        description = "Holodeck Simulation Environment";
        theme = {
          primary = "#FFFFFF";
          secondary = "#C8C8C8";
          accent = "#646464";
          background = "#000000";
          text = "#FFFFFF";
          warning = "#FFA500";
          danger = "#FF0000";
        };
        icon = "${pkgs.holodeck-assets}/share/icons/holodeck.png";
        cursor = "${pkgs.holodeck-assets}/share/cursors/holodeck.cur";
        wallpaper = "${pkgs.holodeck-assets}/share/wallpapers/holodeck-grid.png";
        sounds = {
          startup = "${pkgs.holodeck-assets}/share/sounds/holodeck-start.wav";
          shutdown = "${pkgs.holodeck-assets}/share/sounds/holodeck-end.wav";
          alert = "${pkgs.holodeck-assets}/share/sounds/holodeck-alert.wav";
        };
      };
    };
    
    # Create directories for Holodeck simulations
    system.activationScripts.holodeck = ''
      mkdir -p ${cfg.simulationDirectory}
      chmod 755 ${cfg.simulationDirectory}
    '';
    
    # Install Holodeck packages
    environment.systemPackages = with pkgs; [
      holodeck-simulator
      holodeck-templates
      holodeck-controls
      holodeck-assets
    ];
    
    # Create systemd service for Holodeck simulator
    systemd.services.holodeck-simulator = {
      description = "Holodeck Simulation Environment";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        ExecStart = "${pkgs.holodeck-simulator}/bin/holodeck-simulator";
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = cfg.simulationDirectory;
      };
      
      environment = {
        HOLODECK_TEMPLATE = cfg.defaultTemplate;
        HOLODECK_SECURITY = cfg.securityLevel;
        HOLODECK_PERSIST = lib.boolToString cfg.persistSimulations;
      };
    };
    
    # Add Holodeck-specific firewall rules
    networking.firewall.extraCommands = ''
      # Create Holodeck isolation chain
      iptables -N HOLODECK_ISOLATION || true
      
      # Clear existing rules
      iptables -F HOLODECK_ISOLATION
      
      # Add isolation rules based on security level
      ${if cfg.securityLevel == "maximum" then ''
        # Maximum security: no network access
        iptables -A HOLODECK_ISOLATION -j DROP
      '' else if cfg.securityLevel == "high" then ''
        # High security: only local network
        iptables -A HOLODECK_ISOLATION -d 127.0.0.0/8 -j ACCEPT
        iptables -A HOLODECK_ISOLATION -d 192.168.0.0/16 -j ACCEPT
        iptables -A HOLODECK_ISOLATION -d 10.0.0.0/8 -j ACCEPT
        iptables -A HOLODECK_ISOLATION -j DROP
      '' else if cfg.securityLevel == "medium" then ''
        # Medium security: local network + limited internet
        iptables -A HOLODECK_ISOLATION -d 127.0.0.0/8 -j ACCEPT
        iptables -A HOLODECK_ISOLATION -d 192.168.0.0/16 -j ACCEPT
        iptables -A HOLODECK_ISOLATION -d 10.0.0.0/8 -j ACCEPT
        iptables -A HOLODECK_ISOLATION -p tcp --dport 80 -j ACCEPT
        iptables -A HOLODECK_ISOLATION -p tcp --dport 443 -j ACCEPT
        iptables -A HOLODECK_ISOLATION -j DROP
      '' else ''
        # Low security: full access
        iptables -A HOLODECK_ISOLATION -j ACCEPT
      ''}
      
      # Apply Holodeck isolation when in Holodeck mode
      ${if config.services.mode-switcher.currentMode == "holodeck" then ''
        iptables -A OUTPUT -m owner --uid-owner holodeck -j HOLODECK_ISOLATION
      '' else ''
        # No isolation when not in Holodeck mode
      ''}
    '';
  };
}
```

### 2. Containerization System

#### Requirements
- Create isolated containers for simulations
- Implement resource limits and controls
- Support different container types for different simulations
- Ensure secure isolation between host and simulations

#### Implementation
```nix
# In modules/holodeck/container-system.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.holodeck-containers;
  
  containerType = types.submodule {
    options = {
      image = mkOption {
        type = types.str;
        description = "Container image to use";
      };
      
      resources = {
        cpu = mkOption {
          type = types.int;
          default = 2;
          description = "CPU cores allocated to container";
        };
        
        memory = mkOption {
          type = types.str;
          default = "2G";
          description = "Memory allocated to container";
        };
        
        disk = mkOption {
          type = types.str;
          default = "10G";
          description = "Disk space allocated to container";
        };
      };
      
      network = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable network access";
        };
        
        type = mkOption {
          type = types.enum [ "bridge" "host" "none" "isolated" ];
          default = "isolated";
          description = "Network type for container";
        };
      };
      
      security = {
        privileged = mkOption {
          type = types.bool;
          default = false;
          description = "Run container in privileged mode";
        };
        
        capabilities = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Additional capabilities for container";
        };
      };
    };
  };
in {
  options.services.holodeck-containers = {
    enable = mkEnableOption "Holodeck containerization system";
    
    backend = mkOption {
      type = types.enum [ "podman" "docker" "lxc" "systemd-nspawn" ];
      default = "podman";
      description = "Container backend to use";
    };
    
    templates = mkOption {
      type = types.attrsOf containerType;
      default = {
        "starship-bridge" = {
          image = "holodeck/starship-bridge:latest";
          resources = {
            cpu = 2;
            memory = "4G";
            disk = "10G";
          };
          network = {
            enable = true;
            type = "isolated";
          };
          security = {
            privileged = false;
            capabilities = [];
          };
        };
        
        "engineering-lab" = {
          image = "holodeck/engineering-lab:latest";
          resources = {
            cpu = 4;
            memory = "8G";
            disk = "20G";
          };
          network = {
            enable = true;
            type = "isolated";
          };
          security = {
            privileged = false;
            capabilities = [ "NET_ADMIN" ];
          };
        };
        
        "tactical-simulation" = {
          image = "holodeck/tactical-sim:latest";
          resources = {
            cpu = 4;
            memory = "8G";
            disk = "15G";
          };
          network = {
            enable = true;
            type = "isolated";
          };
          security = {
            privileged = false;
            capabilities = [ "NET_ADMIN" "SYS_PTRACE" ];
          };
        };
        
        "science-lab" = {
          image = "holodeck/science-lab:latest";
          resources = {
            cpu = 2;
            memory = "4G";
            disk = "20G";
          };
          network = {
            enable = true;
            type = "isolated";
          };
          security = {
            privileged = false;
            capabilities = [];
          };
        };
      };
      description = "Container templates for simulations";
    };
    
    storageLocation = mkOption {
      type = types.str;
      default = "/var/lib/holodeck/containers";
      description = "Location for container storage";
    };
  };
  
  config = mkIf cfg.enable {
    # Install container backend
    environment.systemPackages = with pkgs; [
      (if cfg.backend == "podman" then podman
       else if cfg.backend == "docker" then docker
       else if cfg.backend == "lxc" then lxc
       else systemd-container)
    ];
    
    # Enable container service
    virtualisation = {
      podman = mkIf (cfg.backend == "podman") {
        enable = true;
        dockerCompat = true;
      };
      
      docker = mkIf (cfg.backend == "docker") {
        enable = true;
        autoPrune.enable = true;
      };
      
      lxc = mkIf (cfg.backend == "lxc") {
        enable = true;
      };
      
      containers = mkIf (cfg.backend == "systemd-nspawn") {
        enable = true;
        storage.settings = {
          storage.driver = "overlay";
          storage.graphroot = cfg.storageLocation;
        };
      };
    };
    
    # Create storage location
    system.activationScripts.holodeck-containers = ''
      mkdir -p ${cfg.storageLocation}
      chmod 755 ${cfg.storageLocation}
    '';
    
    # Create container management service
    systemd.services.holodeck-container-manager = {
      description = "Holodeck Container Manager";
      wantedBy = [ "multi-user.target" ];
      after = [
        (if cfg.backend == "podman" then "podman.service"
         else if cfg.backend == "docker" then "docker.service"
         else if cfg.backend == "lxc" then "lxc.service"
         else "systemd-nspawn.service")
      ];
      
      serviceConfig = {
        ExecStart = "${pkgs.holodeck-container-manager}/bin/holodeck-container-manager";
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = cfg.storageLocation;
      };
      
      environment = {
        HOLODECK_CONTAINER_BACKEND = cfg.backend;
        HOLODECK_TEMPLATES = builtins.toJSON cfg.templates;
      };
    };
    
    # Add container user
    users.users.holodeck = {
      isSystemUser = true;
      group = "holodeck";
      description = "Holodeck simulation user";
      home = "/var/lib/holodeck";
      createHome = true;
    };
    
    users.groups.holodeck = {};
  };
}
```

### 3. Simulation Framework

#### Requirements
- Create a framework for defining and running simulations
- Support different simulation types and scenarios
- Provide APIs for simulation control and monitoring
- Implement simulation state management

#### Implementation
```python
# src/holodeck/simulator.py
import os
import sys
import json
import logging
import subprocess
import signal
import time
from typing import Dict, List, Optional, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("/var/log/holodeck/simulator.log"),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger("holodeck-simulator")

class HolodeckSimulation:
    """Base class for Holodeck simulations"""
    
    def __init__(self, name: str, template: str, params: Dict[str, Any]):
        self.name = name
        self.template = template
        self.params = params
        self.container_id = None
        self.status = "initialized"
        self.start_time = None
        self.end_time = None
    
    def start(self) -> bool:
        """Start the simulation"""
        logger.info(f"Starting simulation {self.name} with template {self.template}")
        
        # Get container backend from environment
        backend = os.environ.get("HOLODECK_CONTAINER_BACKEND", "podman")
        
        # Get template configuration
        templates = json.loads(os.environ.get("HOLODECK_TEMPLATES", "{}"))
        template_config = templates.get(self.template, {})
        
        if not template_config:
            logger.error(f"Template {self.template} not found")
            return False
        
        # Build container command
        cmd = []
        
        if backend == "podman":
            cmd = [
                "podman", "run", "-d",
                "--name", f"holodeck-{self.name}",
                "--cpu-shares", str(template_config.get("resources", {}).get("cpu", 2) * 1024),
                "--memory", template_config.get("resources", {}).get("memory", "2G"),
                "--storage-opt", f"size={template_config.get('resources', {}).get('disk', '10G')}",
            ]
            
            # Network configuration
            if template_config.get("network", {}).get("enable", True):
                network_type = template_config.get("network", {}).get("type", "isolated")
                if network_type == "bridge":
                    cmd.extend(["--network", "bridge"])
                elif network_type == "host":
                    cmd.extend(["--network", "host"])
                elif network_type == "none":
                    cmd.extend(["--network", "none"])
                else:  # isolated
                    cmd.extend(["--network", "container:holodeck-network"])
            else:
                cmd.extend(["--network", "none"])
            
            # Security configuration
            if template_config.get("security", {}).get("privileged", False):
                cmd.append("--privileged")
            
            for cap in template_config.get("security", {}).get("capabilities", []):
                cmd.extend(["--cap-add", cap])
            
            # Environment variables
            for key, value in self.params.items():
                cmd.extend(["-e", f"{key}={value}"])
            
            # Add image
            cmd.append(template_config.get("image", "holodeck/default:latest"))
        
        elif backend == "docker":
            # Similar to podman but with docker command
            cmd = [
                "docker", "run", "-d",
                "--name", f"holodeck-{self.name}",
                "--cpu-shares", str(template_config.get("resources", {}).get("cpu", 2) * 1024),
                "--memory", template_config.get("resources", {}).get("memory", "2G"),
                "--storage-opt", f"size={template_config.get('resources', {}).get('disk', '10G')}",
            ]
            
            # Rest of docker configuration similar to podman
            # ...
        
        elif backend == "lxc":
            # LXC specific commands
            # ...
        
        elif backend == "systemd-nspawn":
            # systemd-nspawn specific commands
            # ...
        
        # Execute container command
        try:
            logger.info(f"Executing command: {' '.join(cmd)}")
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to start container: {result.stderr}")
                return False
            
            self.container_id = result.stdout.strip()
            self.status = "running"
            self.start_time = time.time()
            
            logger.info(f"Simulation {self.name} started with container ID {self.container_id}")
            return True
        
        except Exception as e:
            logger.error(f"Error starting simulation: {str(e)}")
            return False
    
    def stop(self) -> bool:
        """Stop the simulation"""
        if not self.container_id:
            logger.warning(f"Simulation {self.name} not running")
            return False
        
        logger.info(f"Stopping simulation {self.name}")
        
        # Get container backend from environment
        backend = os.environ.get("HOLODECK_CONTAINER_BACKEND", "podman")
        
        # Build stop command
        cmd = []
        
        if backend == "podman":
            cmd = ["podman", "stop", self.container_id]
        elif backend == "docker":
            cmd = ["docker", "stop", self.container_id]
        elif backend == "lxc":
            cmd = ["lxc-stop", "-n", f"holodeck-{self.name}"]
        elif backend == "systemd-nspawn":
            cmd = ["machinectl", "stop", f"holodeck-{self.name}"]
        
        # Execute stop command
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to stop container: {result.stderr}")
                return False
            
            self.status = "stopped"
            self.end_time = time.time()
            
            logger.info(f"Simulation {self.name} stopped")
            return True
        
        except Exception as e:
            logger.error(f"Error stopping simulation: {str(e)}")
            return False
    
    def pause(self) -> bool:
        """Pause the simulation"""
        if not self.container_id:
            logger.warning(f"Simulation {self.name} not running")
            return False
        
        logger.info(f"Pausing simulation {self.name}")
        
        # Get container backend from environment
        backend = os.environ.get("HOLODECK_CONTAINER_BACKEND", "podman")
        
        # Build pause command
        cmd = []
        
        if backend == "podman":
            cmd = ["podman", "pause", self.container_id]
        elif backend == "docker":
            cmd = ["docker", "pause", self.container_id]
        elif backend == "lxc":
            cmd = ["lxc-freeze", "-n", f"holodeck-{self.name}"]
        elif backend == "systemd-nspawn":
            # systemd-nspawn doesn't support pause, so we'll use SIGSTOP
            cmd = ["machinectl", "kill", f"holodeck-{self.name}", "--signal=SIGSTOP"]
        
        # Execute pause command
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to pause container: {result.stderr}")
                return False
            
            self.status = "paused"
            
            logger.info(f"Simulation {self.name} paused")
            return True
        
        except Exception as e:
            logger.error(f"Error pausing simulation: {str(e)}")
            return False
    
    def resume(self) -> bool:
        """Resume the simulation"""
        if not self.container_id:
            logger.warning(f"Simulation {self.name} not running")
            return False
        
        if self.status != "paused":
            logger.warning(f"Simulation {self.name} not paused")
            return False
        
        logger.info(f"Resuming simulation {self.name}")
        
        # Get container backend from environment
        backend = os.environ.get("HOLODECK_CONTAINER_BACKEND", "podman")
        
        # Build resume command
        cmd = []
        
        if backend == "podman":
            cmd = ["podman", "unpause", self.container_id]
        elif backend == "docker":
            cmd = ["docker", "unpause", self.container_id]
        elif backend == "lxc":
            cmd = ["lxc-unfreeze", "-n", f"holodeck-{self.name}"]
        elif backend == "systemd-nspawn":
            # systemd-nspawn doesn't support unpause, so we'll use SIGCONT
            cmd = ["machinectl", "kill", f"holodeck-{self.name}", "--signal=SIGCONT"]
        
        # Execute resume command
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode != 0:
                logger.error(f"Failed to resume container: {result.stderr}")
                return False
            
            self.status = "running"
            
            logger.info(f"Simulation {self.name} resumed")
            return True
        
        except Exception as e:
            logger.error(f"Error resuming simulation: {str(e)}")
            return False
    
    def get_status(self) -> Dict[str, Any]:
        """Get simulation status"""
        return {
            "name": self.name,
            "template": self.template,
            "status": self.status,
            "container_id": self.container_id,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "runtime": time.time() - self.start_time if self.start_time else None
        }


class HolodeckSimulator:
    """Main Holodeck simulator class"""
    
    def __init__(self):
        self.simulations = {}
        self.default_template = os.environ.get("HOLODECK_TEMPLATE", "starship-bridge")
        self.security_level = os.environ.get("HOLODECK_SECURITY", "high")
        self.persist = os.environ.get("HOLODECK_PERSIST", "true").lower() == "true"
        
        # Create simulation directory if it doesn't exist
        os.makedirs("/var/lib/holodeck/simulations", exist_ok=True)
        
        # Load persisted simulations if enabled
        if self.persist:
            self._load_simulations()
    
    def _load_simulations(self):
        """Load persisted simulations"""
        try:
            sim_dir = "/var/lib/holodeck/simulations"
            for filename in os.listdir(sim_dir):
                if filename.endswith(".json"):
                    with open(os.path.join(sim_dir, filename), "r") as f:
                        sim_data = json.load(f)
                        
                        # Create simulation object
                        sim = HolodeckSimulation(
                            sim_data["name"],
                            sim_data["template"],
                            sim_data["params"]
                        )
                        
                        # Restore simulation state
                        sim.container_id = sim_data.get("container_id")
                        sim.status = sim_data.get("status", "stopped")
                        sim.start_time = sim_data.get("start_time")
                        sim.end_time = sim_data.get("end_time")
                        
                        # Add to simulations dict
                        self.simulations[sim.name] = sim
                        
                        logger.info(f"Loaded simulation {sim.name} from disk")
        
        except Exception as e:
            logger.error(f"Error loading simulations: {str(e)}")
    
    def _save_simulation(self, simulation: HolodeckSimulation):
        """Save simulation to disk"""
        if not self.persist:
            return
        
        try:
            sim_dir = "/var/lib/holodeck/simulations"
            filename = os.path.join(sim_dir, f"{simulation.name}.json")
            
            sim_data = {
                "name": simulation.name,
                "template": simulation.template,
                "params": simulation.params,
                "container_id": simulation.container_id,
                "status": simulation.status,
                "start_time": simulation.start_time,
                "end_time": simulation.end_time
            }
            
            with open(filename, "w") as f:
                json.dump(sim_data, f, indent=2)
            
            logger.info(f"Saved simulation {simulation.name} to disk")
        
        except Exception as e:
            logger.error(f"Error saving simulation {simulation.name}: {str(e)}")
    
    def create_simulation(self, name: str, template: str = None, params: Dict[str, Any] = None) -> Optional[HolodeckSimulation]:
        """Create a new simulation"""
        if name in self.simulations:
            logger.warning(f"Simulation {name} already exists")
            return None
        
        template = template or self.default_template
        params = params or {}
        
        # Create simulation
        simulation = HolodeckSimulation(name, template, params)
        self.simulations[name] = simulation
        
        # Save simulation
        self._save_simulation(simulation)
        
        logger.info(f"Created simulation {name} with template {template}")
        return simulation
    
    def start_simulation(self, name: str) -> bool:
        """Start a simulation"""
        if name not in self.simulations:
            logger.warning(f"Simulation {name} not found")
            return False
        
        simulation = self.simulations[name]
        result = simulation.start()
        
        if result:
            self._save_simulation(simulation)
        
        return result
    
    def stop_simulation(self, name: str) -> bool:
        """Stop a simulation"""
        if name not in self.simulations:
            logger.warning(f"Simulation {name} not found")
            return False
        
        simulation = self.simulations[name]
        result = simulation.stop()
        
        if result:
            self._save_simulation(simulation)
        
        return result
    
    def pause_simulation(self, name: str) -> bool:
        """Pause a simulation"""
        if name not in self.simulations:
            logger.warning(f"Simulation {name} not found")
            return False
        
        simulation = self.simulations[name]
        result = simulation.pause()
        
        if result:
            self._save_simulation(simulation)
        
        return result
    
    def resume_simulation(self, name: str) -> bool:
        """Resume a simulation"""
        if name not in self.simulations:
            logger.warning(f"Simulation {name} not found")
            return False
        
        simulation = self.simulations[name]
        result = simulation.resume()
        
        if result:
            self._save_simulation(simulation)
        
        return result
    
    def delete_simulation(self, name: str) -> bool:
        """Delete a simulation"""
        if name not in self.simulations:
            logger.warning(f"Simulation {name} not found")
            return False
        
        simulation = self.simulations[name]
        
        # Stop simulation if running
        if simulation.status in ["running", "paused"]:
            simulation.stop()
        
        # Remove container
        try:
            backend = os.environ.get("HOLODECK_CONTAINER_BACKEND", "podman")
            
            if backend == "podman":
                cmd = ["podman", "rm", "-f", f"holodeck-{name}"]
            elif backend == "docker":
                cmd = ["docker", "rm", "-f", f"holodeck-{name}"]
            elif backend == "lxc":
                cmd = ["lxc-destroy", "-n", f"holodeck-{name}"]
            elif backend == "systemd-nspawn":
                cmd = ["machinectl", "remove", f"holodeck-{name}"]
            
            subprocess.run(cmd, capture_output=True, text=True)
        except Exception as e:
            logger.error(f"Error removing container: {str(e)}")
        
        # Remove from simulations dict
        del self.simulations[name]
        
        # Remove saved file
        if self.persist:
            try:
                sim_file = f"/var/lib/holodeck/simulations/{name}.json"
                if os.path.exists(sim_file):
                    os.remove(sim_file)
            except Exception as e:
                logger.error(f"Error removing simulation file: {str(e)}")
        
        logger.info(f"Deleted simulation {name}")
        return True
    
    def list_simulations(self) -> List[Dict[str, Any]]:
        """List all simulations"""
        return [sim.get_status() for sim in self.simulations.values()]
    
    def get_simulation(self, name: str) -> Optional[Dict[str, Any]]:
        """Get simulation status"""
        if name not in self.simulations:
            logger.warning(f"Simulation {name} not found")
            return None
        
        return self.simulations[name].get_status()
    
    def run_api_server(self):
        """Run API server for simulation control"""
        # This would be implemented with a web framework like Flask
        # For brevity, we'll just log that it would start here
        logger.info("Starting Holodeck API server")
        
        # In a real implementation, this would start a web server
        # that provides REST APIs for controlling simulations
        
        # For now, we'll just sleep to keep the process running
        try:
            while True:
                time.sleep(60)
        except KeyboardInterrupt:
            logger.info("Shutting down Holodeck simulator")


def main():
    """Main entry point"""
    simulator = HolodeckSimulator()
    
    # Create default simulation if none exist
    if not simulator.simulations:
        simulator.create_simulation("default")
    
    # Run API server
    simulator.run_api_server()


if __name__ == "__main__":
    main()
```

### 4. Holodeck UI

#### Requirements
- Create LCARS-themed UI for Holodeck control
- Implement simulation management interface
- Provide visualization of simulation status
- Support template selection and customization

#### Implementation
```nix
# In pkgs/holodeck-ui/default.nix
{ lib, stdenv, fetchFromGitHub, python3Packages, gtk3, wrapGAppsHook }:

python3Packages.buildPythonApplication {
  pname = "holodeck-ui";
  version = "1.0.0";
  
  src = ./src;
  
  buildInputs = [
    gtk3
  ];
  
  nativeBuildInputs = [
    wrapGAppsHook
  ];
  
  propagatedBuildInputs = with python3Packages; [
    pygobject3
    requests
    pyyaml
    pillow
    matplotlib
  ];
  
  doCheck = false;
  
  meta = with lib; {
    description = "LCARS-themed UI for Holodeck simulation control";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
```

```python
# src/holodeck_ui/main.py
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib
import os
import sys
import json
import requests
import threading
import time
import yaml
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.expanduser("~/.local/share/holodeck/ui.log")),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger("holodeck-ui")

class HolodeckUI:
    """LCARS-themed UI for Holodeck simulation control"""
    
    def __init__(self):
        # Load CSS
        css_provider = Gtk.CssProvider()
        css_provider.load_from_path("/usr/share/holodeck/ui/lcars.css")
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        
        # Create window
        self.window = Gtk.Window(title="Holodeck Control")
        self.window.set_default_size(1024, 768)
        self.window.connect("destroy", Gtk.main_quit)
        self.window.get_style_context().add_class("lcars-window")
        
        # Create main box
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.window.add(self.main_box)
        
        # Create header
        self.header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.header.get_style_context().add_class("lcars-header")
        self.main_box.pack_start(self.header, False, False, 0)
        
        # Create header label
        self.header_label = Gtk.Label(label="HOLODECK CONTROL")
        self.header_label.get_style_context().add_class("lcars-header-text")
        self.header.pack_start(self.header_label, True, True, 10)
        
        # Create content area
        self.content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.main_box.pack_start(self.content, True, True, 0)
        
        # Create sidebar
        self.sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.sidebar.set_size_request(200, -1)
        self.sidebar.get_style_context().add_class("lcars-sidebar")
        self.content.pack_start(self.sidebar, False, False, 0)
        
        # Create sidebar buttons
        self.create_sidebar_button("SIMULATIONS", self.show_simulations)
        self.create_sidebar_button("TEMPLATES", self.show_templates)
        self.create_sidebar_button("SETTINGS", self.show_settings)
        self.create_sidebar_button("STATUS", self.show_status)
        self.create_sidebar_button("EXIT", Gtk.main_quit)
        
        # Create main content area
        self.main_content = Gtk.Stack()
        self.main_content.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.main_content.set_transition_duration(300)
        self.content.pack_start(self.main_content, True, True, 0)
        
        # Create simulations page
        self.simulations_page = self.create_simulations_page()
        self.main_content.add_named(self.simulations_page, "simulations")
        
        # Create templates page
        self.templates_page = self.create_templates_page()
        self.main_content.add_named(self.templates_page, "templates")
        
        # Create settings page
        self.settings_page = self.create_settings_page()
        self.main_content.add_named(self.settings_page, "settings")
        
        # Create status page
        self.status_page = self.create_status_page()
        self.main_content.add_named(self.status_page, "status")
        
        # Create footer
        self.footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self.footer.get_style_context().add_class("lcars-footer")
        self.main_box.pack_start(self.footer, False, False, 0)
        
        # Create footer label
        self.footer_label = Gtk.Label(label="STARFLEET OS - HOLODECK MODE")
        self.footer_label.get_style_context().add_class("lcars-footer-text")
        self.footer.pack_start(self.footer_label, True, True, 10)
        
        # Show simulations page by default
        self.main_content.set_visible_child_name("simulations")
        
        # Start update thread
        self.update_thread = threading.Thread(target=self.update_loop)
        self.update_thread.daemon = True
        self.update_thread.start()
    
    def create_sidebar_button(self, label, callback):
        """Create a sidebar button"""
        button = Gtk.Button(label=label)
        button.get_style_context().add_class("lcars-button")
        button.connect("clicked", lambda w: callback())
        self.sidebar.pack_start(button, False, False, 5)
        return button
    
    def create_simulations_page(self):
        """Create simulations page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        # Create header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        page.pack_start(header, False, False, 0)
        
        # Create title
        title = Gtk.Label(label="ACTIVE SIMULATIONS")
        title.get_style_context().add_class("lcars-title")
        header.pack_start(title, True, True, 0)
        
        # Create new simulation button
        new_button = Gtk.Button(label="NEW SIMULATION")
        new_button.get_style_context().add_class("lcars-button")
        new_button.connect("clicked", self.on_new_simulation)
        header.pack_start(new_button, False, False, 0)
        
        # Create simulations list
        self.simulations_list = Gtk.ListBox()
        self.simulations_list.get_style_context().add_class("lcars-list")
        self.simulations_list.connect("row-activated", self.on_simulation_activated)
        
        # Create scrolled window for simulations list
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.add(self.simulations_list)
        page.pack_start(scrolled, True, True, 0)
        
        return page
    
    def create_templates_page(self):
        """Create templates page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        # Create header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        page.pack_start(header, False, False, 0)
        
        # Create title
        title = Gtk.Label(label="SIMULATION TEMPLATES")
        title.get_style_context().add_class("lcars-title")
        header.pack_start(title, True, True, 0)
        
        # Create templates list
        self.templates_list = Gtk.ListBox()
        self.templates_list.get_style_context().add_class("lcars-list")
        self.templates_list.connect("row-activated", self.on_template_activated)
        
        # Create scrolled window for templates list
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.add(self.templates_list)
        page.pack_start(scrolled, True, True, 0)
        
        # Load templates
        self.load_templates()
        
        return page
    
    def create_settings_page(self):
        """Create settings page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        # Create header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        page.pack_start(header, False, False, 0)
        
        # Create title
        title = Gtk.Label(label="HOLODECK SETTINGS")
        title.get_style_context().add_class("lcars-title")
        header.pack_start(title, True, True, 0)
        
        # Create settings grid
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(10)
        grid.set_margin_top(20)
        page.pack_start(grid, False, False, 0)
        
        # Security level
        security_label = Gtk.Label(label="SECURITY LEVEL:")
        security_label.get_style_context().add_class("lcars-label")
        security_label.set_halign(Gtk.Align.START)
        grid.attach(security_label, 0, 0, 1, 1)
        
        self.security_combo = Gtk.ComboBoxText()
        self.security_combo.get_style_context().add_class("lcars-combo")
        self.security_combo.append_text("LOW")
        self.security_combo.append_text("MEDIUM")
        self.security_combo.append_text("HIGH")
        self.security_combo.append_text("MAXIMUM")
        self.security_combo.set_active(2)  # Default to HIGH
        grid.attach(self.security_combo, 1, 0, 1, 1)
        
        # Persist simulations
        persist_label = Gtk.Label(label="PERSIST SIMULATIONS:")
        persist_label.get_style_context().add_class("lcars-label")
        persist_label.set_halign(Gtk.Align.START)
        grid.attach(persist_label, 0, 1, 1, 1)
        
        self.persist_switch = Gtk.Switch()
        self.persist_switch.get_style_context().add_class("lcars-switch")
        self.persist_switch.set_active(True)
        grid.attach(self.persist_switch, 1, 1, 1, 1)
        
        # Default template
        template_label = Gtk.Label(label="DEFAULT TEMPLATE:")
        template_label.get_style_context().add_class("lcars-label")
        template_label.set_halign(Gtk.Align.START)
        grid.attach(template_label, 0, 2, 1, 1)
        
        self.template_combo = Gtk.ComboBoxText()
        self.template_combo.get_style_context().add_class("lcars-combo")
        grid.attach(self.template_combo, 1, 2, 1, 1)
        
        # Container backend
        backend_label = Gtk.Label(label="CONTAINER BACKEND:")
        backend_label.get_style_context().add_class("lcars-label")
        backend_label.set_halign(Gtk.Align.START)
        grid.attach(backend_label, 0, 3, 1, 1)
        
        self.backend_combo = Gtk.ComboBoxText()
        self.backend_combo.get_style_context().add_class("lcars-combo")
        self.backend_combo.append_text("PODMAN")
        self.backend_combo.append_text("DOCKER")
        self.backend_combo.append_text("LXC")
        self.backend_combo.append_text("SYSTEMD-NSPAWN")
        self.backend_combo.set_active(0)  # Default to PODMAN
        grid.attach(self.backend_combo, 1, 3, 1, 1)
        
        # Save button
        save_button = Gtk.Button(label="SAVE SETTINGS")
        save_button.get_style_context().add_class("lcars-button")
        save_button.connect("clicked", self.on_save_settings)
        grid.attach(save_button, 0, 4, 2, 1)
        
        # Load settings
        self.load_settings()
        
        return page
    
    def create_status_page(self):
        """Create status page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        page.set_margin_top(10)
        page.set_margin_bottom(10)
        page.set_margin_start(10)
        page.set_margin_end(10)
        
        # Create header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        page.pack_start(header, False, False, 0)
        
        # Create title
        title = Gtk.Label(label="HOLODECK STATUS")
        title.get_style_context().add_class("lcars-title")
        header.pack_start(title, True, True, 0)
        
        # Create status grid
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(10)
        grid.set_margin_top(20)
        page.pack_start(grid, False, False, 0)
        
        # API status
        api_label = Gtk.Label(label="API STATUS:")
        api_label.get_style_context().add_class("lcars-label")
        api_label.set_halign(Gtk.Align.START)
        grid.attach(api_label, 0, 0, 1, 1)
        
        self.api_status = Gtk.Label(label="UNKNOWN")
        self.api_status.get_style_context().add_class("lcars-value")
        self.api_status.set_halign(Gtk.Align.START)
        grid.attach(self.api_status, 1, 0, 1, 1)
        
        # Container service
        container_label = Gtk.Label(label="CONTAINER SERVICE:")
        container_label.get_style_context().add_class("lcars-label")
        container_label.set_halign(Gtk.Align.START)
        grid.attach(container_label, 0, 1, 1, 1)
        
        self.container_status = Gtk.Label(label="UNKNOWN")
        self.container_status.get_style_context().add_class("lcars-value")
        self.container_status.set_halign(Gtk.Align.START)
        grid.attach(self.container_status, 1, 1, 1, 1)
        
        # Active simulations
        active_label = Gtk.Label(label="ACTIVE SIMULATIONS:")
        active_label.get_style_context().add_class("lcars-label")
        active_label.set_halign(Gtk.Align.START)
        grid.attach(active_label, 0, 2, 1, 1)
        
        self.active_count = Gtk.Label(label="0")
        self.active_count.get_style_context().add_class("lcars-value")
        self.active_count.set_halign(Gtk.Align.START)
        grid.attach(self.active_count, 1, 2, 1, 1)
        
        # System resources
        resources_label = Gtk.Label(label="SYSTEM RESOURCES:")
        resources_label.get_style_context().add_class("lcars-label")
        resources_label.set_halign(Gtk.Align.START)
        grid.attach(resources_label, 0, 3, 1, 1)
        
        self.resources_status = Gtk.Label(label="UNKNOWN")
        self.resources_status.get_style_context().add_class("lcars-value")
        self.resources_status.set_halign(Gtk.Align.START)
        grid.attach(self.resources_status, 1, 3, 1, 1)
        
        # Refresh button
        refresh_button = Gtk.Button(label="REFRESH STATUS")
        refresh_button.get_style_context().add_class("lcars-button")
        refresh_button.connect("clicked", self.on_refresh_status)
        grid.attach(refresh_button, 0, 4, 2, 1)
        
        return page
    
    def show_simulations(self):
        """Show simulations page"""
        self.main_content.set_visible_child_name("simulations")
        self.update_simulations_list()
    
    def show_templates(self):
        """Show templates page"""
        self.main_content.set_visible_child_name("templates")
    
    def show_settings(self):
        """Show settings page"""
        self.main_content.set_visible_child_name("settings")
    
    def show_status(self):
        """Show status page"""
        self.main_content.set_visible_child_name("status")
        self.update_status()
    
    def load_templates(self):
        """Load simulation templates"""
        try:
            # Clear templates list
            for child in self.templates_list.get_children():
                self.templates_list.remove(child)
            
            # Load templates from API
            response = requests.get("http://localhost:8080/api/templates")
            templates = response.json()
            
            # Add templates to list
            for template in templates:
                row = Gtk.ListBoxRow()
                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                box.set_margin_top(5)
                box.set_margin_bottom(5)
                box.set_margin_start(5)
                box.set_margin_end(5)
                
                # Template name
                name = Gtk.Label(label=template["name"])
                name.get_style_context().add_class("lcars-list-title")
                name.set_halign(Gtk.Align.START)
                box.pack_start(name, True, True, 0)
                
                # Template description
                description = Gtk.Label(label=template["description"])
                description.get_style_context().add_class("lcars-list-subtitle")
                description.set_halign(Gtk.Align.START)
                box.pack_start(description, True, True, 0)
                
                row.add(box)
                self.templates_list.add(row)
            
            # Add templates to template combo
            self.template_combo.remove_all()
            for template in templates:
                self.template_combo.append_text(template["name"])
            self.template_combo.set_active(0)
            
            self.templates_list.show_all()
        
        except Exception as e:
            logger.error(f"Error loading templates: {str(e)}")
    
    def load_settings(self):
        """Load Holodeck settings"""
        try:
            # Load settings from API
            response = requests.get("http://localhost:8080/api/settings")
            settings = response.json()
            
            # Set security level
            security_level = settings.get("security_level", "high").upper()
            if security_level == "LOW":
                self.security_combo.set_active(0)
            elif security_level == "MEDIUM":
                self.security_combo.set_active(1)
            elif security_level == "HIGH":
                self.security_combo.set_active(2)
            else:
                self.security_combo.set_active(3)
            
            # Set persist simulations
            self.persist_switch.set_active(settings.get("persist", True))
            
            # Set default template
            default_template = settings.get("default_template", "starship-bridge")
            for i in range(self.template_combo.get_model().iter_n_children(None)):
                if self.template_combo.get_model()[i][0] == default_template:
                    self.template_combo.set_active(i)
                    break
            
            # Set container backend
            backend = settings.get("backend", "podman").upper()
            if backend == "PODMAN":
                self.backend_combo.set_active(0)
            elif backend == "DOCKER":
                self.backend_combo.set_active(1)
            elif backend == "LXC":
                self.backend_combo.set_active(2)
            else:
                self.backend_combo.set_active(3)
        
        except Exception as e:
            logger.error(f"Error loading settings: {str(e)}")
    
    def update_simulations_list(self):
        """Update simulations list"""
        try:
            # Clear simulations list
            for child in self.simulations_list.get_children():
                self.simulations_list.remove(child)
            
            # Load simulations from API
            response = requests.get("http://localhost:8080/api/simulations")
            simulations = response.json()
            
            # Add simulations to list
            for simulation in simulations:
                row = Gtk.ListBoxRow()
                box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                box.set_margin_top(5)
                box.set_margin_bottom(5)
                box.set_margin_start(5)
                box.set_margin_end(5)
                
                # Simulation name
                name = Gtk.Label(label=simulation["name"])
                name.get_style_context().add_class("lcars-list-title")
                name.set_halign(Gtk.Align.START)
                box.pack_start(name, True, True, 0)
                
                # Simulation status
                status = Gtk.Label(label=simulation["status"].upper())
                status.get_style_context().add_class("lcars-list-subtitle")
                status.set_halign(Gtk.Align.START)
                box.pack_start(status, True, True, 0)
                
                # Control buttons
                if simulation["status"] == "running":
                    # Pause button
                    pause_button = Gtk.Button(label="PAUSE")
                    pause_button.get_style_context().add_class("lcars-button")
                    pause_button.connect("clicked", lambda w, s=simulation["name"]: self.on_pause_simulation(s))
                    box.pack_start(pause_button, False, False, 0)
                    
                    # Stop button
                    stop_button = Gtk.Button(label="STOP")
                    stop_button.get_style_context().add_class("lcars-button")
                    stop_button.connect("clicked", lambda w, s=simulation["name"]: self.on_stop_simulation(s))
                    box.pack_start(stop_button, False, False, 0)
                
                elif simulation["status"] == "paused":
                    # Resume button
                    resume_button = Gtk.Button(label="RESUME")
                    resume_button.get_style_context().add_class("lcars-button")
                    resume_button.connect("clicked", lambda w, s=simulation["name"]: self.on_resume_simulation(s))
                    box.pack_start(resume_button, False, False, 0)
                    
                    # Stop button
                    stop_button = Gtk.Button(label="STOP")
                    stop_button.get_style_context().add_class("lcars-button")
                    stop_button.connect("clicked", lambda w, s=simulation["name"]: self.on_stop_simulation(s))
                    box.pack_start(stop_button, False, False, 0)
                
                else:  # stopped or initialized
                    # Start button
                    start_button = Gtk.Button(label="START")
                    start_button.get_style_context().add_class("lcars-button")
                    start_button.connect("clicked", lambda w, s=simulation["name"]: self.on_start_simulation(s))
                    box.pack_start(start_button, False, False, 0)
                    
                    # Delete button
                    delete_button = Gtk.Button(label="DELETE")
                    delete_button.get_style_context().add_class("lcars-button")
                    delete_button.connect("clicked", lambda w, s=simulation["name"]: self.on_delete_simulation(s))
                    box.pack_start(delete_button, False, False, 0)
                
                row.add(box)
                self.simulations_list.add(row)
            
            self.simulations_list.show_all()
        
        except Exception as e:
            logger.error(f"Error updating simulations list: {str(e)}")
    
    def update_status(self):
        """Update status page"""
        try:
            # Check API status
            try:
                response = requests.get("http://localhost:8080/api/status")
                if response.status_code == 200:
                    self.api_status.set_text("ONLINE")
                    self.api_status.get_style_context().remove_class("lcars-value-error")
                    self.api_status.get_style_context().add_class("lcars-value-ok")
                else:
                    self.api_status.set_text("ERROR")
                    self.api_status.get_style_context().remove_class("lcars-value-ok")
                    self.api_status.get_style_context().add_class("lcars-value-error")
            except:
                self.api_status.set_text("OFFLINE")
                self.api_status.get_style_context().remove_class("lcars-value-ok")
                self.api_status.get_style_context().add_class("lcars-value-error")
            
            # Check container service
            try:
                response = requests.get("http://localhost:8080/api/container-status")
                if response.status_code == 200:
                    status = response.json().get("status", "UNKNOWN")
                    self.container_status.set_text(status)
                    if status == "RUNNING":
                        self.container_status.get_style_context().remove_class("lcars-value-error")
                        self.container_status.get_style_context().add_class("lcars-value-ok")
                    else:
                        self.container_status.get_style_context().remove_class("lcars-value-ok")
                        self.container_status.get_style_context().add_class("lcars-value-error")
                else:
                    self.container_status.set_text("ERROR")
                    self.container_status.get_style_context().remove_class("lcars-value-ok")
                    self.container_status.get_style_context().add_class("lcars-value-error")
            except:
                self.container_status.set_text("UNKNOWN")
                self.container_status.get_style_context().remove_class("lcars-value-ok")
                self.container_status.get_style_context().add_class("lcars-value-error")
            
            # Check active simulations
            try:
                response = requests.get("http://localhost:8080/api/simulations")
                if response.status_code == 200:
                    simulations = response.json()
                    active_count = sum(1 for sim in simulations if sim["status"] in ["running", "paused"])
                    self.active_count.set_text(str(active_count))
                else:
                    self.active_count.set_text("ERROR")
            except:
                self.active_count.set_text("UNKNOWN")
            
            # Check system resources
            try:
                response = requests.get("http://localhost:8080/api/resources")
                if response.status_code == 200:
                    resources = response.json()
                    cpu_usage = resources.get("cpu_usage", 0)
                    memory_usage = resources.get("memory_usage", 0)
                    disk_usage = resources.get("disk_usage", 0)
                    
                    status_text = f"CPU: {cpu_usage}% MEM: {memory_usage}% DISK: {disk_usage}%"
                    self.resources_status.set_text(status_text)
                    
                    if cpu_usage > 90 or memory_usage > 90 or disk_usage > 90:
                        self.resources_status.get_style_context().remove_class("lcars-value-ok")
                        self.resources_status.get_style_context().add_class("lcars-value-error")
                    else:
                        self.resources_status.get_style_context().remove_class("lcars-value-error")
                        self.resources_status.get_style_context().add_class("lcars-value-ok")
                else:
                    self.resources_status.set_text("ERROR")
                    self.resources_status.get_style_context().remove_class("lcars-value-ok")
                    self.resources_status.get_style_context().add_class("lcars-value-error")
            except:
                self.resources_status.set_text("UNKNOWN")
                self.resources_status.get_style_context().remove_class("lcars-value-ok")
                self.resources_status.get_style_context().add_class("lcars-value-error")
        
        except Exception as e:
            logger.error(f"Error updating status: {str(e)}")
    
    def on_new_simulation(self, button):
        """Handle new simulation button click"""
        # Create dialog
        dialog = Gtk.Dialog(title="New Simulation", parent=self.window, flags=0)
        dialog.get_style_context().add_class("lcars-dialog")
        dialog.add_button("CANCEL", Gtk.ResponseType.CANCEL)
        dialog.add_button("CREATE", Gtk.ResponseType.OK)
        
        # Create content area
        content_area = dialog.get_content_area()
        content_area.set_margin_top(10)
        content_area.set_margin_bottom(10)
        content_area.set_margin_start(10)
        content_area.set_margin_end(10)
        
        # Create grid
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(10)
        content_area.add(grid)
        
        # Simulation name
        name_label = Gtk.Label(label="NAME:")
        name_label.get_style_context().add_class("lcars-label")
        name_label.set_halign(Gtk.Align.START)
        grid.attach(name_label, 0, 0, 1, 1)
        
        name_entry = Gtk.Entry()
        name_entry.get_style_context().add_class("lcars-entry")
        grid.attach(name_entry, 1, 0, 1, 1)
        
        # Template
        template_label = Gtk.Label(label="TEMPLATE:")
        template_label.get_style_context().add_class("lcars-label")
        template_label.set_halign(Gtk.Align.START)
        grid.attach(template_label, 0, 1, 1, 1)
        
        template_combo = Gtk.ComboBoxText()
        template_combo.get_style_context().add_class("lcars-combo")
        
        # Load templates
        try:
            response = requests.get("http://localhost:8080/api/templates")
            templates = response.json()
            
            for template in templates:
                template_combo.append_text(template["name"])
            
            template_combo.set_active(0)
        except:
            template_combo.append_text("starship-bridge")
            template_combo.set_active(0)
        
        grid.attach(template_combo, 1, 1, 1, 1)
        
        # Show dialog
        dialog.show_all()
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            # Get values
            name = name_entry.get_text()
            template = template_combo.get_active_text()
            
            # Create simulation
            try:
                response = requests.post(
                    "http://localhost:8080/api/simulations",
                    json={"name": name, "template": template}
                )
                
                if response.status_code == 200:
                    # Update simulations list
                    self.update_simulations_list()
                else:
                    # Show error dialog
                    error_dialog = Gtk.MessageDialog(
                        parent=self.window,
                        flags=0,
                        message_type=Gtk.MessageType.ERROR,
                        buttons=Gtk.ButtonsType.OK,
                        text="Error creating simulation"
                    )
                    error_dialog.format_secondary_text(response.json().get("error", "Unknown error"))
                    error_dialog.run()
                    error_dialog.destroy()
            
            except Exception as e:
                # Show error dialog
                error_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Error creating simulation"
                )
                error_dialog.format_secondary_text(str(e))
                error_dialog.run()
                error_dialog.destroy()
        
        dialog.destroy()
    
    def on_simulation_activated(self, list_box, row):
        """Handle simulation row activation"""
        # Get simulation name
        box = row.get_child()
        name_label = box.get_children()[0]
        name = name_label.get_text()
        
        # Show simulation details
        self.show_simulation_details(name)
    
    def show_simulation_details(self, name):
        """Show simulation details"""
        try:
            # Get simulation details
            response = requests.get(f"http://localhost:8080/api/simulations/{name}")
            simulation = response.json()
            
            # Create dialog
            dialog = Gtk.Dialog(title=f"Simulation: {name}", parent=self.window, flags=0)
            dialog.get_style_context().add_class("lcars-dialog")
            dialog.add_button("CLOSE", Gtk.ResponseType.CLOSE)
            
            # Create content area
            content_area = dialog.get_content_area()
            content_area.set_margin_top(10)
            content_area.set_margin_bottom(10)
            content_area.set_margin_start(10)
            content_area.set_margin_end(10)
            
            # Create grid
            grid = Gtk.Grid()
            grid.set_column_spacing(10)
            grid.set_row_spacing(10)
            content_area.add(grid)
            
            # Simulation name
            name_label = Gtk.Label(label="NAME:")
            name_label.get_style_context().add_class("lcars-label")
            name_label.set_halign(Gtk.Align.START)
            grid.attach(name_label, 0, 0, 1, 1)
            
            name_value = Gtk.Label(label=simulation["name"])
            name_value.get_style_context().add_class("lcars-value")
            name_value.set_halign(Gtk.Align.START)
            grid.attach(name_value, 1, 0, 1, 1)
            
            # Template
            template_label = Gtk.Label(label="TEMPLATE:")
            template_label.get_style_context().add_class("lcars-label")
            template_label.set_halign(Gtk.Align.START)
            grid.attach(template_label, 0, 1, 1, 1)
            
            template_value = Gtk.Label(label=simulation["template"])
            template_value.get_style_context().add_class("lcars-value")
            template_value.set_halign(Gtk.Align.START)
            grid.attach(template_value, 1, 1, 1, 1)
            
            # Status
            status_label = Gtk.Label(label="STATUS:")
            status_label.get_style_context().add_class("lcars-label")
            status_label.set_halign(Gtk.Align.START)
            grid.attach(status_label, 0, 2, 1, 1)
            
            status_value = Gtk.Label(label=simulation["status"].upper())
            status_value.get_style_context().add_class("lcars-value")
            status_value.set_halign(Gtk.Align.START)
            grid.attach(status_value, 1, 2, 1, 1)
            
            # Container ID
            container_label = Gtk.Label(label="CONTAINER ID:")
            container_label.get_style_context().add_class("lcars-label")
            container_label.set_halign(Gtk.Align.START)
            grid.attach(container_label, 0, 3, 1, 1)
            
            container_value = Gtk.Label(label=simulation.get("container_id", "N/A"))
            container_value.get_style_context().add_class("lcars-value")
            container_value.set_halign(Gtk.Align.START)
            grid.attach(container_value, 1, 3, 1, 1)
            
            # Start time
            start_label = Gtk.Label(label="START TIME:")
            start_label.get_style_context().add_class("lcars-label")
            start_label.set_halign(Gtk.Align.START)
            grid.attach(start_label, 0, 4, 1, 1)
            
            start_time = simulation.get("start_time")
            start_value = Gtk.Label(label=time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(start_time)) if start_time else "N/A")
            start_value.get_style_context().add_class("lcars-value")
            start_value.set_halign(Gtk.Align.START)
            grid.attach(start_value, 1, 4, 1, 1)
            
            # Runtime
            runtime_label = Gtk.Label(label="RUNTIME:")
            runtime_label.get_style_context().add_class("lcars-label")
            runtime_label.set_halign(Gtk.Align.START)
            grid.attach(runtime_label, 0, 5, 1, 1)
            
            runtime = simulation.get("runtime")
            runtime_value = Gtk.Label(label=f"{runtime:.2f} seconds" if runtime else "N/A")
            runtime_value.get_style_context().add_class("lcars-value")
            runtime_value.set_halign(Gtk.Align.START)
            grid.attach(runtime_value, 1, 5, 1, 1)
            
            # Control buttons
            button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            grid.attach(button_box, 0, 6, 2, 1)
            
            if simulation["status"] == "running":
                # Pause button
                pause_button = Gtk.Button(label="PAUSE")
                pause_button.get_style_context().add_class("lcars-button")
                pause_button.connect("clicked", lambda w: self.on_pause_simulation(name))
                button_box.pack_start(pause_button, True, True, 0)
                
                # Stop button
                stop_button = Gtk.Button(label="STOP")
                stop_button.get_style_context().add_class("lcars-button")
                stop_button.connect("clicked", lambda w: self.on_stop_simulation(name))
                button_box.pack_start(stop_button, True, True, 0)
            
            elif simulation["status"] == "paused":
                # Resume button
                resume_button = Gtk.Button(label="RESUME")
                resume_button.get_style_context().add_class("lcars-button")
                resume_button.connect("clicked", lambda w: self.on_resume_simulation(name))
                button_box.pack_start(resume_button, True, True, 0)
                
                # Stop button
                stop_button = Gtk.Button(label="STOP")
                stop_button.get_style_context().add_class("lcars-button")
                stop_button.connect("clicked", lambda w: self.on_stop_simulation(name))
                button_box.pack_start(stop_button, True, True, 0)
            
            else:  # stopped or initialized
                # Start button
                start_button = Gtk.Button(label="START")
                start_button.get_style_context().add_class("lcars-button")
                start_button.connect("clicked", lambda w: self.on_start_simulation(name))
                button_box.pack_start(start_button, True, True, 0)
                
                # Delete button
                delete_button = Gtk.Button(label="DELETE")
                delete_button.get_style_context().add_class("lcars-button")
                delete_button.connect("clicked", lambda w: self.on_delete_simulation(name))
                button_box.pack_start(delete_button, True, True, 0)
            
            # Show dialog
            dialog.show_all()
            dialog.run()
            dialog.destroy()
        
        except Exception as e:
            logger.error(f"Error showing simulation details: {str(e)}")
    
    def on_template_activated(self, list_box, row):
        """Handle template row activation"""
        # Get template name
        box = row.get_child()
        name_label = box.get_children()[0]
        name = name_label.get_text()
        
        # Show template details
        self.show_template_details(name)
    
    def show_template_details(self, name):
        """Show template details"""
        try:
            # Get template details
            response = requests.get(f"http://localhost:8080/api/templates/{name}")
            template = response.json()
            
            # Create dialog
            dialog = Gtk.Dialog(title=f"Template: {name}", parent=self.window, flags=0)
            dialog.get_style_context().add_class("lcars-dialog")
            dialog.add_button("CLOSE", Gtk.ResponseType.CLOSE)
            
            # Create content area
            content_area = dialog.get_content_area()
            content_area.set_margin_top(10)
            content_area.set_margin_bottom(10)
            content_area.set_margin_start(10)
            content_area.set_margin_end(10)
            
            # Create grid
            grid = Gtk.Grid()
            grid.set_column_spacing(10)
            grid.set_row_spacing(10)
            content_area.add(grid)
            
            # Template name
            name_label = Gtk.Label(label="NAME:")
            name_label.get_style_context().add_class("lcars-label")
            name_label.set_halign(Gtk.Align.START)
            grid.attach(name_label, 0, 0, 1, 1)
            
            name_value = Gtk.Label(label=template["name"])
            name_value.get_style_context().add_class("lcars-value")
            name_value.set_halign(Gtk.Align.START)
            grid.attach(name_value, 1, 0, 1, 1)
            
            # Description
            desc_label = Gtk.Label(label="DESCRIPTION:")
            desc_label.get_style_context().add_class("lcars-label")
            desc_label.set_halign(Gtk.Align.START)
            grid.attach(desc_label, 0, 1, 1, 1)
            
            desc_value = Gtk.Label(label=template["description"])
            desc_value.get_style_context().add_class("lcars-value")
            desc_value.set_halign(Gtk.Align.START)
            grid.attach(desc_value, 1, 1, 1, 1)
            
            # Image
            image_label = Gtk.Label(label="IMAGE:")
            image_label.get_style_context().add_class("lcars-label")
            image_label.set_halign(Gtk.Align.START)
            grid.attach(image_label, 0, 2, 1, 1)
            
            image_value = Gtk.Label(label=template["image"])
            image_value.get_style_context().add_class("lcars-value")
            image_value.set_halign(Gtk.Align.START)
            grid.attach(image_value, 1, 2, 1, 1)
            
            # Resources
            resources_label = Gtk.Label(label="RESOURCES:")
            resources_label.get_style_context().add_class("lcars-label")
            resources_label.set_halign(Gtk.Align.START)
            grid.attach(resources_label, 0, 3, 1, 1)
            
            resources = template.get("resources", {})
            resources_value = Gtk.Label(
                label=f"CPU: {resources.get('cpu', 2)} cores, "
                      f"Memory: {resources.get('memory', '2G')}, "
                      f"Disk: {resources.get('disk', '10G')}"
            )
            resources_value.get_style_context().add_class("lcars-value")
            resources_value.set_halign(Gtk.Align.START)
            grid.attach(resources_value, 1, 3, 1, 1)
            
            # Network
            network_label = Gtk.Label(label="NETWORK:")
            network_label.get_style_context().add_class("lcars-label")
            network_label.set_halign(Gtk.Align.START)
            grid.attach(network_label, 0, 4, 1, 1)
            
            network = template.get("network", {})
            network_value = Gtk.Label(
                label=f"Enabled: {network.get('enable', True)}, "
                      f"Type: {network.get('type', 'isolated')}"
            )
            network_value.get_style_context().add_class("lcars-value")
            network_value.set_halign(Gtk.Align.START)
            grid.attach(network_value, 1, 4, 1, 1)
            
            # Security
            security_label = Gtk.Label(label="SECURITY:")
            security_label.get_style_context().add_class("lcars-label")
            security_label.set_halign(Gtk.Align.START)
            grid.attach(security_label, 0, 5, 1, 1)
            
            security = template.get("security", {})
            security_value = Gtk.Label(
                label=f"Privileged: {security.get('privileged', False)}, "
                      f"Capabilities: {', '.join(security.get('capabilities', []))}"
            )
            security_value.get_style_context().add_class("lcars-value")
            security_value.set_halign(Gtk.Align.START)
            grid.attach(security_value, 1, 5, 1, 1)
            
            # Create simulation button
            create_button = Gtk.Button(label="CREATE SIMULATION")
            create_button.get_style_context().add_class("lcars-button")
            create_button.connect("clicked", lambda w: self.create_simulation_from_template(name))
            grid.attach(create_button, 0, 6, 2, 1)
            
            # Show dialog
            dialog.show_all()
            dialog.run()
            dialog.destroy()
        
        except Exception as e:
            logger.error(f"Error showing template details: {str(e)}")
    
    def create_simulation_from_template(self, template_name):
        """Create a simulation from a template"""
        # Create dialog
        dialog = Gtk.Dialog(title="New Simulation", parent=self.window, flags=0)
        dialog.get_style_context().add_class("lcars-dialog")
        dialog.add_button("CANCEL", Gtk.ResponseType.CANCEL)
        dialog.add_button("CREATE", Gtk.ResponseType.OK)
        
        # Create content area
        content_area = dialog.get_content_area()
        content_area.set_margin_top(10)
        content_area.set_margin_bottom(10)
        content_area.set_margin_start(10)
        content_area.set_margin_end(10)
        
        # Create grid
        grid = Gtk.Grid()
        grid.set_column_spacing(10)
        grid.set_row_spacing(10)
        content_area.add(grid)
        
        # Simulation name
        name_label = Gtk.Label(label="NAME:")
        name_label.get_style_context().add_class("lcars-label")
        name_label.set_halign(Gtk.Align.START)
        grid.attach(name_label, 0, 0, 1, 1)
        
        name_entry = Gtk.Entry()
        name_entry.get_style_context().add_class("lcars-entry")
        grid.attach(name_entry, 1, 0, 1, 1)
        
        # Template
        template_label = Gtk.Label(label="TEMPLATE:")
        template_label.get_style_context().add_class("lcars-label")
        template_label.set_halign(Gtk.Align.START)
        grid.attach(template_label, 0, 1, 1, 1)
        
        template_value = Gtk.Label(label=template_name)
        template_value.get_style_context().add_class("lcars-value")
        template_value.set_halign(Gtk.Align.START)
        grid.attach(template_value, 1, 1, 1, 1)
        
        # Show dialog
        dialog.show_all()
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            # Get values
            name = name_entry.get_text()
            
            # Create simulation
            try:
                response = requests.post(
                    "http://localhost:8080/api/simulations",
                    json={"name": name, "template": template_name}
                )
                
                if response.status_code == 200:
                    # Update simulations list
                    self.update_simulations_list()
                else:
                    # Show error dialog
                    error_dialog = Gtk.MessageDialog(
                        parent=self.window,
                        flags=0,
                        message_type=Gtk.MessageType.ERROR,
                        buttons=Gtk.ButtonsType.OK,
                        text="Error creating simulation"
                    )
                    error_dialog.format_secondary_text(response.json().get("error", "Unknown error"))
                    error_dialog.run()
                    error_dialog.destroy()
            
            except Exception as e:
                # Show error dialog
                error_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Error creating simulation"
                )
                error_dialog.format_secondary_text(str(e))
                error_dialog.run()
                error_dialog.destroy()
        
        dialog.destroy()
    
    def on_start_simulation(self, name):
        """Start a simulation"""
        try:
            response = requests.post(f"http://localhost:8080/api/simulations/{name}/start")
            
            if response.status_code == 200:
                # Update simulations list
                self.update_simulations_list()
            else:
                # Show error dialog
                error_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Error starting simulation"
                )
                error_dialog.format_secondary_text(response.json().get("error", "Unknown error"))
                error_dialog.run()
                error_dialog.destroy()
        
        except Exception as e:
            # Show error dialog
            error_dialog = Gtk.MessageDialog(
                parent=self.window,
                flags=0,
                message_type=Gtk.MessageType.ERROR,
                buttons=Gtk.ButtonsType.OK,
                text="Error starting simulation"
            )
            error_dialog.format_secondary_text(str(e))
            error_dialog.run()
            error_dialog.destroy()
    
    def on_stop_simulation(self, name):
        """Stop a simulation"""
        try:
            response = requests.post(f"http://localhost:8080/api/simulations/{name}/stop")
            
            if response.status_code == 200:
                # Update simulations list
                self.update_simulations_list()
            else:
                # Show error dialog
                error_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Error stopping simulation"
                )
                error_dialog.format_secondary_text(response.json().get("error", "Unknown error"))
                error_dialog.run()
                error_dialog.destroy()
        
        except Exception as e:
            # Show error dialog
            error_dialog = Gtk.MessageDialog(
                parent=self.window,
                flags=0,
                message_type=Gtk.MessageType.ERROR,
                buttons=Gtk.ButtonsType.OK,
                text="Error stopping simulation"
            )
            error_dialog.format_secondary_text(str(e))
            error_dialog.run()
            error_dialog.destroy()
    
    def on_pause_simulation(self, name):
        """Pause a simulation"""
        try:
            response = requests.post(f"http://localhost:8080/api/simulations/{name}/pause")
            
            if response.status_code == 200:
                # Update simulations list
                self.update_simulations_list()
            else:
                # Show error dialog
                error_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Error pausing simulation"
                )
                error_dialog.format_secondary_text(response.json().get("error", "Unknown error"))
                error_dialog.run()
                error_dialog.destroy()
        
        except Exception as e:
            # Show error dialog
            error_dialog = Gtk.MessageDialog(
                parent=self.window,
                flags=0,
                message_type=Gtk.MessageType.ERROR,
                buttons=Gtk.ButtonsType.OK,
                text="Error pausing simulation"
            )
            error_dialog.format_secondary_text(str(e))
            error_dialog.run()
            error_dialog.destroy()
    
    def on_resume_simulation(self, name):
        """Resume a simulation"""
        try:
            response = requests.post(f"http://localhost:8080/api/simulations/{name}/resume")
            
            if response.status_code == 200:
                # Update simulations list
                self.update_simulations_list()
            else:
                # Show error dialog
                error_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Error resuming simulation"
                )
                error_dialog.format_secondary_text(response.json().get("error", "Unknown error"))
                error_dialog.run()
                error_dialog.destroy()
        
        except Exception as e:
            # Show error dialog
            error_dialog = Gtk.MessageDialog(
                parent=self.window,
                flags=0,
                message_type=Gtk.MessageType.ERROR,
                buttons=Gtk.ButtonsType.OK,
                text="Error resuming simulation"
            )
            error_dialog.format_secondary_text(str(e))
            error_dialog.run()
            error_dialog.destroy()
    
    def on_delete_simulation(self, name):
        """Delete a simulation"""
        # Create confirmation dialog
        dialog = Gtk.MessageDialog(
            parent=self.window,
            flags=0,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Delete Simulation"
        )
        dialog.format_secondary_text(f"Are you sure you want to delete simulation '{name}'?")
        response = dialog.run()
        dialog.destroy()
        
        if response == Gtk.ResponseType.YES:
            try:
                response = requests.delete(f"http://localhost:8080/api/simulations/{name}")
                
                if response.status_code == 200:
                    # Update simulations list
                    self.update_simulations_list()
                else:
                    # Show error dialog
                    error_dialog = Gtk.MessageDialog(
                        parent=self.window,
                        flags=0,
                        message_type=Gtk.MessageType.ERROR,
                        buttons=Gtk.ButtonsType.OK,
                        text="Error deleting simulation"
                    )
                    error_dialog.format_secondary_text(response.json().get("error", "Unknown error"))
                    error_dialog.run()
                    error_dialog.destroy()
            
            except Exception as e:
                # Show error dialog
                error_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Error deleting simulation"
                )
                error_dialog.format_secondary_text(str(e))
                error_dialog.run()
                error_dialog.destroy()
    
    def on_save_settings(self, button):
        """Save settings"""
        try:
            # Get settings
            security_level = self.security_combo.get_active_text().lower()
            persist = self.persist_switch.get_active()
            default_template = self.template_combo.get_active_text()
            backend = self.backend_combo.get_active_text().lower()
            
            # Save settings
            response = requests.post(
                "http://localhost:8080/api/settings",
                json={
                    "security_level": security_level,
                    "persist": persist,
                    "default_template": default_template,
                    "backend": backend
                }
            )
            
            if response.status_code == 200:
                # Show success dialog
                success_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.INFO,
                    buttons=Gtk.ButtonsType.OK,
                    text="Settings Saved"
                )
                success_dialog.format_secondary_text("Settings have been saved successfully.")
                success_dialog.run()
                success_dialog.destroy()
            else:
                # Show error dialog
                error_dialog = Gtk.MessageDialog(
                    parent=self.window,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Error saving settings"
                )
                error_dialog.format_secondary_text(response.json().get("error", "Unknown error"))
                error_dialog.run()
                error_dialog.destroy()
        
        except Exception as e:
            # Show error dialog
            error_dialog = Gtk.MessageDialog(
                parent=self.window,
                flags=0,
                message_type=Gtk.MessageType.ERROR,
                buttons=Gtk.ButtonsType.OK,
                text="Error saving settings"
            )
            error_dialog.format_secondary_text(str(e))
            error_dialog.run()
            error_dialog.destroy()
    
    def on_refresh_status(self, button):
        """Refresh status"""
        self.update_status()
    
    def update_loop(self):
        """Update loop for UI"""
        while True:
            # Update simulations list
            GLib.idle_add(self.update_simulations_list)
            
            # Update status
            GLib.idle_add(self.update_status)
            
            # Sleep for 5 seconds
            time.sleep(5)


def main():
    """Main entry point"""
    ui = HolodeckUI()
    ui.window.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
```

### 5. Simulation Templates

#### Requirements
- Create templates for different simulation scenarios
- Support customization of templates
- Implement resource allocation for templates
- Provide documentation for template creation

#### Implementation
```yaml
# templates/starship-bridge.yaml
name: starship-bridge
description: Starfleet Command Bridge Simulation
image: holodeck/starship-bridge:latest
resources:
  cpu: 2
  memory: 4G
  disk: 10G
network:
  enable: true
  type: isolated
security:
  privileged: false
  capabilities: []
parameters:
  ship_class: galaxy
  crew_complement: 1000
  mission_type: exploration
applications:
  - lcars-bridge-console
  - tactical-display
  - navigation-controls
  - communication-system
documentation: |
  # Starship Bridge Simulation
  
  This simulation provides a complete starship bridge environment with all
  command and control systems. It includes tactical, navigation, and
  communication interfaces in a full LCARS environment.
  
  ## Features
  
  - Complete bridge layout with all stations
  - Tactical display with simulated sensor readings
  - Navigation controls with stellar cartography
  - Communication system with simulated subspace channels
  - Engineering status displays
  - Science station with sensor controls
  
  ## Usage
  
  1. Start the simulation
  2. Access the main viewscreen using the LCARS interface
  3. Interact with bridge stations using the control panels
  4. Run simulated missions using the mission control panel
```

```yaml
# templates/engineering-lab.yaml
name: engineering-lab
description: Engineering and Systems Development Lab
image: holodeck/engineering-lab:latest
resources:
  cpu: 4
  memory: 8G
  disk: 20G
network:
  enable: true
  type: isolated
security:
  privileged: false
  capabilities:
    - NET_ADMIN
parameters:
  lab_type: warp_core
  simulation_level: advanced
  safety_protocols: enabled
applications:
  - warp-core-simulator
  - power-distribution-lab
  - materials-testing
  - structural-integrity-field
documentation: |
  # Engineering Lab Simulation
  
  This simulation provides a complete engineering laboratory environment for
  testing and developing starship systems. It includes warp core simulation,
  power distribution analysis, and materials testing facilities.
  
  ## Features
  
  - Warp core simulation with matter/antimatter reaction monitoring
  - Power distribution grid with load balancing tools
  - Materials testing facility with stress analysis
  - Structural integrity field simulation
  - Environmental systems laboratory
  
  ## Usage
  
  1. Start the simulation
  2. Select the engineering system to work with
  3. Configure simulation parameters
  4. Run tests and analyze results
  5. Export findings for implementation
```

```yaml
# templates/tactical-simulation.yaml
name: tactical-simulation
description: Combat and Defense Simulation Environment
image: holodeck/tactical-sim:latest
resources:
  cpu: 4
  memory: 8G
  disk: 15G
network:
  enable: true
  type: isolated
security:
  privileged: false
  capabilities:
    - NET_ADMIN
    - SYS_PTRACE
parameters:
  scenario_type: defense
  difficulty: advanced
  opponents: klingon
  ship_class: sovereign
applications:
  - tactical-simulator
  - weapons-control
  - shield-management
  - battle-strategy-advisor
documentation: |
  # Tactical Simulation Environment
  
  This simulation provides a tactical training environment for combat and
  defense scenarios. It includes weapons control, shield management, and
  battle strategy tools.
  
  ## Features
  
  - Realistic combat scenarios with multiple opponent types
  - Weapons targeting and control systems
  - Shield management with power allocation
  - Battle strategy advisor with tactical recommendations
  - After-action analysis and performance metrics
  
  ## Usage
  
  1. Start the simulation
  2. Select a scenario from the tactical database
  3. Configure ship systems and readiness level
  4. Engage the simulation and respond to threats
  5. Review performance metrics after completion
```

```yaml
# templates/science-lab.yaml
name: science-lab
description: Scientific Research and Analysis Laboratory
image: holodeck/science-lab:latest
resources:
  cpu: 2
  memory: 4G
  disk: 20G
network:
  enable: true
  type: isolated
security:
  privileged: false
  capabilities: []
parameters:
  lab_type: astrometrics
  research_focus: stellar_cartography
  sensor_resolution: high
applications:
  - astrometrics-lab
  - sensor-analysis
  - research-database
  - specimen-analysis
documentation: |
  # Science Laboratory Simulation
  
  This simulation provides a complete scientific research laboratory with
  astrometrics, sensor analysis, and specimen research facilities.
  
  ## Features
  
  - Astrometrics lab with stellar cartography
  - High-resolution sensor analysis tools
  - Research database with Federation scientific archives
  - Specimen analysis with molecular scanning
  - Experimental design and hypothesis testing tools
  
  ## Usage
  
  1. Start the simulation
  2. Select a research focus area
  3. Configure laboratory equipment and parameters
  4. Conduct experiments and gather data
  5. Analyze results and prepare research reports
```

## Testing Plan

### 1. Virtual Machine Testing
- Test Holodeck mode in QEMU/VirtualBox
- Verify container isolation works correctly
- Test with different simulation templates
- Verify resource limits are enforced

### 2. Hardware Testing
- Test on OptiPlex bridge hardware
- Test with different container backends
- Verify hardware acceleration works correctly
- Test with different security levels

### 3. Security Testing
- Test container isolation
- Verify network isolation works correctly
- Test with different security levels
- Attempt to break out of containers

## Integration with Existing Components

### 1. Mode Switcher Integration
```nix
# In modules/modes/mode-switcher.nix
{ config, lib, pkgs, ... }:

# Add to existing mode-switcher.nix
{
  config = mkIf cfg.enable {
    # Existing configuration...
    
    # Add Holodeck mode configuration
    services.holodeck-mode = mkIf (cfg.currentMode == "holodeck") {
      enable = true;
      defaultTemplate = "starship-bridge";
      securityLevel = "high";
      persistSimulations = true;
    };
    
    # Add container system configuration
    services.holodeck-containers = mkIf (cfg.currentMode == "holodeck") {
      enable = true;
      backend = "podman";
    };
    
    # Update system when mode changes to/from Holodeck
    system.activationScripts.updateHolodeckMode = ''
      if [ "${cfg.currentMode}" = "holodeck" ]; then
        # Enable Holodeck services
        systemctl start holodeck-simulator
        systemctl start holodeck-container-manager
      else
        # Disable Holodeck services if they're running
        systemctl stop holodeck-simulator || true
        systemctl stop holodeck-container-manager || true
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
    
    # Add Holodeck mode integration
    services.lcars-display.holodeckIntegration = mkIf config.services.holodeck-mode.enable {
      enable = true;
      simulationDisplay = true;
    };
    
    # Add Holodeck UI to display server
    environment.systemPackages = with pkgs; [
      holodeck-ui
    ];
    
    # Add desktop entry for Holodeck UI
    environment.etc."xdg/autostart/holodeck-ui.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Holodeck Control
      Comment=LCARS Holodeck Simulation Control
      Exec=${pkgs.holodeck-ui}/bin/holodeck-ui
      Terminal=false
      Categories=System;
      OnlyShowIn=lcars;
    '';
  };
}
```

## Deliverables

1. **Holodeck Mode**: Complete Holodeck operational mode for Starfleet OS
2. **Container System**: Secure containerization system for simulations
3. **Simulation Framework**: Framework for defining and running simulations
4. **Holodeck UI**: LCARS-themed UI for Holodeck control
5. **Simulation Templates**: Templates for different simulation scenarios
6. **NixOS Modules**: NixOS modules for Holodeck mode configuration
7. **Documentation**: Complete documentation for the Holodeck mode

## Timeline

1. **Week 1**: Design and implement Holodeck mode switcher integration
2. **Week 2**: Create containerization system
3. **Week 3**: Implement simulation framework
4. **Week 4**: Create Holodeck UI
5. **Week 5**: Develop simulation templates
6. **Week 6**: Testing and optimization

## Conclusion

The Holodeck mode implementation will provide a secure, isolated simulation environment for testing, training, and experimentation within Starfleet OS. By following the Star Trek concept of a programmable environment for simulations, users will be able to create and run various scenarios in a safe and controlled manner. The implementation will maintain the LCARS design language while providing powerful containerization and simulation capabilities.