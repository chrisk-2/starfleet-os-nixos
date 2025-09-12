{ config, pkgs, ... }:

{
  imports = [
    # Base modules
    ../modules/borg/collective-manager.nix
    ../modules/borg/assimilation-system.nix
    ../modules/borg/adaptation-system.nix
    
    # Service discovery modules
    ../modules/borg/service-discovery/consul-integration.nix
    ../modules/borg/service-discovery/service-registry.nix
    
    # Sensor integration modules
    ../modules/borg/sensor-integration/home-assistant-integration.nix
    ../modules/borg/sensor-integration/mqtt-broker.nix
  ];

  # Basic system configuration for Raspberry Pi
  boot.loader.raspberryPi = {
    enable = true;
    version = 3;
    firmwareConfig = ''
      gpu_mem=256
      dtparam=audio=on
      dtparam=i2c_arm=on
      dtparam=spi=on
      dtoverlay=gpio-ir
    '';
  };
  
  networking.hostName = "borg-edge-pi";
  networking.networkmanager.enable = true;

  # Enable Borg Collective Manager
  services.borg.collective-manager = {
    enable = true;
    role = "edge";
    droneId = "edge-pi";
    queenAddress = "10.42.0.1";
    adaptationLevel = "low";
    regenerationEnabled = true;
    collectiveAwareness = true;
    
    # API configuration
    apiEnabled = true;
    apiPort = 8080;
    apiAuth = true;
    apiToken = "borg-collective-token";
  };

  # Enable Borg Assimilation System
  services.borg.assimilation-system = {
    enable = true;
    role = "edge";
    queenAddress = "10.42.0.1";
    assimilationSpeed = "slow";
    retentionPolicy = "preserve";
  };

  # Enable Borg Adaptation System
  services.borg.adaptation-system = {
    enable = true;
    role = "edge";
    centralNode = "10.42.0.1";
    selfHealingEnabled = true;
    learningEnabled = false;
  };

  # Enable Consul integration
  services.borg.discovery.consul = {
    enable = true;
    role = "client";
    datacenter = "borg-collective";
    nodeName = "borg-edge-pi";
    serverNodes = [ "10.42.0.1" ];
    encryptionKey = "borg-collective-encryption-key";
  };

  # Enable service registry
  services.borg.discovery.registry = {
    enable = true;
    autoRegisterServices = true;
    services = {
      "edge-pi-sensor" = {
        name = "edge-pi-sensor";
        tags = [ "sensor" "edge" ];
        address = "10.42.0.5";
        port = 8080;
        checks = [
          {
            type = "http";
            target = "http://localhost:8080/health";
            interval = "30s";
          }
        ];
      };
    };
  };

  # Enable Home Assistant
  services.borg.sensors.homeAssistant = {
    enable = true;
    deployment = "local";
    borgIntegration = true;
    mqttIntegration = true;
    mqttBroker = "10.42.0.1";
    mqttPort = 1883;
    mqttUsername = "homeassistant";
    mqttPassword = "homeassistant-password";
    config = {
      # Additional Home Assistant configuration
      default_config = {};
      
      # Sensors
      sensor = [
        {
          platform = "systemmonitor";
          resources = [
            { type = "disk_use_percent"; arg = "/"; }
            { type = "memory_use_percent"; }
            { type = "processor_use"; }
            { type = "last_boot"; }
          ];
        }
      ];
      
      # Camera integration
      camera = [
        {
          platform = "rpi_camera";
          name = "Borg Eye";
        }
      ];
      
      # Binary sensors
      binary_sensor = [
        {
          platform = "gpio";
          name = "Motion Sensor";
          port = 17;
          pull_mode = "UP";
          bouncetime = 50;
          invert_logic = false;
        }
      ];
      
      # Automations
      automation = [
        {
          alias = "Motion Detection Alert";
          trigger = {
            platform = "state";
            entity_id = "binary_sensor.motion_sensor";
            to = "on";
          };
          action = {
            service = "mqtt.publish";
            data = {
              topic = "borg/sensors/motion";
              payload = "detected";
            };
          };
        }
      ];
    };
  };

  # Enable MQTT client
  services.borg.sensors.mqtt = {
    enable = true;
    deployment = "local";
    port = 1883;
    allowAnonymous = false;
    users = {
      "edge-pi" = {
        password = "edge-pi-password";
        acl = [ "readwrite sensors/edge-pi/#" "read #" ];
      };
    };
  };

  # Enable GPIO for sensors
  hardware.gpio.enable = true;
  hardware.i2c.enable = true;
  hardware.spi.enable = true;

  # Enable camera
  hardware.raspberry-pi.camera.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    # System utilities
    vim
    wget
    git
    htop
    curl
    jq
    
    # Python packages for sensors
    python3
    python3Packages.pip
    python3Packages.gpiozero
    python3Packages.adafruit-blinka
    python3Packages.adafruit-circuitpython-dht
    
    # Sensor tools
    i2c-tools
    wiringpi
    
    # Networking tools
    nmap
    tcpdump
  ];

  # Enable SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = false;

  # User configuration
  users.users.borg = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "gpio" "i2c" "spi" "video" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... borg@collective"
    ];
  };

  # Create sensor service
  systemd.services.borg-sensor-service = {
    description = "Borg Edge PI Sensor Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "borg";
      Group = "borg";
      ExecStart = pkgs.writeScript "sensor-service" ''
        #!${pkgs.python3}/bin/python3
        
        import time
        import json
        import http.server
        import socketserver
        import threading
        import paho.mqtt.client as mqtt
        from gpiozero import MotionSensor, LED, Button
        
        # Configure sensors
        pir = MotionSensor(17)
        led = LED(27)
        button = Button(22)
        
        # Configure MQTT
        mqtt_client = mqtt.Client()
        mqtt_client.username_pw_set("edge-pi", "edge-pi-password")
        mqtt_client.connect("10.42.0.1", 1883, 60)
        mqtt_client.loop_start()
        
        # Sensor data
        sensor_data = {
            "temperature": 22.5,
            "humidity": 45.0,
            "motion": False,
            "button_pressed": False,
            "status": "online"
        }
        
        # Sensor callbacks
        def motion_detected():
            sensor_data["motion"] = True
            led.on()
            mqtt_client.publish("sensors/edge-pi/motion", "detected")
            print("Motion detected!")
            
        def motion_ended():
            sensor_data["motion"] = False
            led.off()
            mqtt_client.publish("sensors/edge-pi/motion", "clear")
            print("Motion ended")
            
        def button_pressed():
            sensor_data["button_pressed"] = True
            mqtt_client.publish("sensors/edge-pi/button", "pressed")
            print("Button pressed!")
            
        def button_released():
            sensor_data["button_pressed"] = False
            mqtt_client.publish("sensors/edge-pi/button", "released")
            print("Button released")
        
        # Register callbacks
        pir.when_motion = motion_detected
        pir.when_no_motion = motion_ended
        button.when_pressed = button_pressed
        button.when_released = button_released
        
        # HTTP server for API
        class SensorHandler(http.server.SimpleHTTPRequestHandler):
            def do_GET(self):
                if self.path == '/health':
                    self.send_response(200)
                    self.send_header('Content-type', 'text/plain')
                    self.end_headers()
                    self.wfile.write(b'OK')
                elif self.path == '/api/sensors':
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps(sensor_data).encode())
                else:
                    self.send_response(404)
                    self.end_headers()
        
        # Start HTTP server
        httpd = socketserver.TCPServer(("", 8080), SensorHandler)
        print("Server started at http://localhost:8080")
        
        # Periodic sensor update
        def update_sensors():
            while True:
                # In a real application, read from actual sensors
                # For now, we'll just simulate some changes
                sensor_data["temperature"] += (random.random() - 0.5)
                sensor_data["humidity"] += (random.random() - 0.5)
                
                # Publish to MQTT
                mqtt_client.publish("sensors/edge-pi/temperature", str(sensor_data["temperature"]))
                mqtt_client.publish("sensors/edge-pi/humidity", str(sensor_data["humidity"]))
                
                time.sleep(60)
        
        # Start sensor update thread
        import random
        sensor_thread = threading.Thread(target=update_sensors)
        sensor_thread.daemon = True
        sensor_thread.start()
        
        # Main loop
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
        finally:
            httpd.server_close()
            mqtt_client.loop_stop()
            mqtt_client.disconnect()
      '';
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # System settings
  system.stateVersion = "24.05";
}