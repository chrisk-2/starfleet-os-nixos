{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.virtualization.templates;
in {
  options.services.borg.virtualization.templates = {
    enable = mkEnableOption "Borg Collective VM templates";
    
    templateDir = mkOption {
      type = types.path;
      default = "/var/lib/vz/template";
      description = "Directory for VM templates";
    };
    
    nixosTemplate = mkOption {
      type = types.bool;
      default = true;
      description = "Create NixOS VM template";
    };
    
    nixosIsoUrl = mkOption {
      type = types.str;
      default = "https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso";
      description = "URL to NixOS ISO for template";
    };
    
    borgTemplate = mkOption {
      type = types.bool;
      default = true;
      description = "Create Borg Collective VM template";
    };
    
    borgIsoUrl = mkOption {
      type = types.str;
      default = "https://starfleet-os.example.com/iso/borg-collective-latest.iso";
      description = "URL to Borg Collective ISO for template";
    };
  };
  
  config = mkIf cfg.enable {
    # Install required packages
    environment.systemPackages = with pkgs; [
      wget
      qemu-utils
      gptfdisk
      parted
    ];
    
    # Create directory for templates
    systemd.tmpfiles.rules = [
      "d ${cfg.templateDir} 0755 root root -"
      "d ${cfg.templateDir}/iso 0755 root root -"
    ];
    
    # Create NixOS template
    systemd.services.create-nixos-template = mkIf cfg.nixosTemplate {
      description = "Create NixOS VM template";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''
        # Download NixOS ISO if not present
        ISO_FILE="${cfg.templateDir}/iso/nixos.iso"
        if [ ! -f "$ISO_FILE" ]; then
          wget -O "$ISO_FILE" "${cfg.nixosIsoUrl}"
        fi
        
        # Create VM template if it doesn't exist
        if ! qm list | grep -q "9000"; then
          # Create VM
          qm create 9000 --name nixos-template --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0
          
          # Create and attach disk
          qm set 9000 --scsi0 local-lvm:32G
          
          # Configure boot
          qm set 9000 --boot c --bootdisk scsi0
          
          # Attach ISO
          qm set 9000 --ide2 local:iso/nixos.iso,media=cdrom
          
          # Configure display and serial
          qm set 9000 --serial0 socket --vga serial0
          
          # Convert to template
          qm template 9000
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Create Borg Collective template
    systemd.services.create-borg-template = mkIf cfg.borgTemplate {
      description = "Create Borg Collective VM template";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''
        # Download Borg Collective ISO if not present
        ISO_FILE="${cfg.templateDir}/iso/borg-collective.iso"
        if [ ! -f "$ISO_FILE" ]; then
          wget -O "$ISO_FILE" "${cfg.borgIsoUrl}"
        fi
        
        # Create VM template if it doesn't exist
        if ! qm list | grep -q "9001"; then
          # Create VM
          qm create 9001 --name borg-collective-template --memory 8192 --cores 4 --net0 virtio,bridge=vmbr0
          
          # Create and attach disk
          qm set 9001 --scsi0 local-lvm:64G
          
          # Configure boot
          qm set 9001 --boot c --bootdisk scsi0
          
          # Attach ISO
          qm set 9001 --ide2 local:iso/borg-collective.iso,media=cdrom
          
          # Configure display and serial
          qm set 9001 --serial0 socket --vga serial0
          
          # Convert to template
          qm template 9001
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      vmTemplates = {
        nixos = mkIf cfg.nixosTemplate {
          id = 9000;
          name = "nixos-template";
          description = "NixOS template for Borg Collective";
        };
        
        borgCollective = mkIf cfg.borgTemplate {
          id = 9001;
          name = "borg-collective-template";
          description = "Borg Collective template for assimilation";
        };
      };
    };
  };
}