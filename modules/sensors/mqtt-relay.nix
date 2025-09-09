{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mqtt-relay;
in
{
  options.services.mqtt-relay = {
    enable = mkEnableOption "Starfleet OS MQTT Relay";
    
    brokerHost = mkOption {
      type = types.str;
      default = "borg-drone-alpha";
      description = "MQTT broker host";
    };
    
    brokerPort = mkOption {
      type = types.int;
      default = 1883;
      description = "MQTT broker port";
    };
    
    clientId = mkOption {
      type = types.str;
      default = "starfleet-mqtt-relay";
      description = "MQTT client ID";
    };
    
    username = mkOption {
      type = types.str;
      default = "mqtt-relay";
      description = "MQTT username";
    };
    
    password = mkOption {
      type = types.str;
      default = "mqtt-relay-password";
      description = "MQTT password";
    };
    
    topicPrefix = mkOption {
      type = types.str;
      default = "starfleet/sensors";
      description = "MQTT topic prefix";
    };
    
    enableGpio = mkOption {
      type = types.bool;
      default = true;
      description = "Enable GPIO sensors";
    };
    
    enableI2c = mkOption {
      type = types.bool;
      default = true;
      description = "Enable I2C sensors";
    };
    
    enableOneWire = mkOption {
      type = types.bool;
      default = true;
      description = "Enable 1-Wire sensors";
    };
    
    sensorInterval = mkOption {
      type = types.int;
      default = 60;
      description = "Sensor reading interval in seconds";
    };
  };

  config = mkIf cfg.enable {
    # MQTT broker
    services.mosquitto = {
      enable = true;
      
      listeners = [
        {
          port = cfg.brokerPort;
          users = {
            ${cfg.username} = {
              acl = [ "pattern readwrite ${cfg.topicPrefix}/#" ];
              password = cfg.password;
            };
          };
        }
      ];
    };
    
    # GPIO configuration
    hardware.gpio = mkIf cfg.enableGpio {
      enable = true;
    };
    
    # I2C configuration
    hardware.i2c = mkIf cfg.enableI2c {
      enable = true;
    };
    
    # 1-Wire configuration
    hardware.deviceTree = mkIf cfg.enableOneWire {
      overlays = [
        {
          name = "w1-gpio";
          dtsText = ''
            /dts-v1/;
            /plugin/;
            
            / {
              compatible = "raspberrypi";
              
              fragment@0 {
                target-path = "/";
                __overlay__ {
                  w1: onewire@0 {
                    compatible = "w1-gpio";
                    pinctrl-names = "default";
                    pinctrl-0 = <&w1_pins>;
                    gpios = <&gpio 4 0>;
                    status = "okay";
                  };
                };
              };
              
              fragment@1 {
                target = <&gpio>;
                __overlay__ {
                  w1_pins: w1_pins {
                    brcm,pins = <4>;
                    brcm,function = <0>;
                    brcm,pull = <0>;
                  };
                };
              };
            };
          '';
        }
      ];
    };
    
    # MQTT relay service
    systemd.services.mqtt-relay = {
      description = "Starfleet OS MQTT Relay Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "mosquitto.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "mqtt-relay";
        Group = "mqtt-relay";
        ExecStart = "${pkgs.writeShellScript "mqtt-relay" ''
          #!/bin/bash
          
          BROKER_HOST="${cfg.brokerHost}"
          BROKER_PORT=${toString cfg.brokerPort}
          CLIENT_ID="${cfg.clientId}"
          USERNAME="${cfg.username}"
          PASSWORD="${cfg.password}"
          TOPIC_PREFIX="${cfg.topicPrefix}"
          SENSOR_INTERVAL=${toString cfg.sensorInterval}
          
          echo "Starting Starfleet OS MQTT Relay Service"
          echo "Broker: $BROKER_HOST:$BROKER_PORT"
          echo "Topic prefix: $TOPIC_PREFIX"
          echo "Sensor interval: $SENSOR_INTERVAL seconds"
          
          # Function to read GPIO sensors
          read_gpio_sensors() {
            if ${toString cfg.enableGpio}; then
              echo "Reading GPIO sensors..."
              
              # Read GPIO pins
              for pin in 17 18 27 22; do
                if [ -e /sys/class/gpio/gpio$pin ]; then
                  # Ensure pin is exported and set as input
                  if [ ! -e /sys/class/gpio/gpio$pin ]; then
                    echo $pin > /sys/class/gpio/export
                    echo in > /sys/class/gpio/gpio$pin/direction
                  fi
                  
                  # Read value
                  value=$(cat /sys/class/gpio/gpio$pin/value)
                  
                  # Publish to MQTT
                  ${pkgs.mosquitto}/bin/mosquitto_pub -h "$BROKER_HOST" -p "$BROKER_PORT" \
                    -t "$TOPIC_PREFIX/gpio/pin$pin" -m "$value" \
                    -u "$USERNAME" -P "$PASSWORD" \
                    -i "$CLIENT_ID" -r
                fi
              done
            fi
          }
          
          # Function to read I2C sensors
          read_i2c_sensors() {
            if ${toString cfg.enableI2c}; then
              echo "Reading I2C sensors..."
              
              # Check for BME280 sensor (temperature, humidity, pressure)
              if [ -e /dev/i2c-1 ]; then
                # Use Python to read BME280
                ${pkgs.python3}/bin/python3 -c "
                import smbus2
                import bme280
                
                try:
                    bus = smbus2.SMBus(1)
                    calibration_params = bme280.load_calibration_params(bus, 0x76)
                    data = bme280.sample(bus, 0x76, calibration_params)
                    
                    # Print sensor data
                    print(f'Temperature: {data.temperature:.2f}°C')
                    print(f'Humidity: {data.humidity:.2f}%')
                    print(f'Pressure: {data.pressure:.2f}hPa')
                    
                    # Publish to MQTT
                    import subprocess
                    
                    subprocess.run([
                        '${pkgs.mosquitto}/bin/mosquitto_pub',
                        '-h', '${cfg.brokerHost}',
                        '-p', '${toString cfg.brokerPort}',
                        '-t', '${cfg.topicPrefix}/bme280/temperature',
                        '-m', f'{data.temperature:.2f}',
                        '-u', '${cfg.username}',
                        '-P', '${cfg.password}',
                        '-i', '${cfg.clientId}',
                        '-r'
                    ])
                    
                    subprocess.run([
                        '${pkgs.mosquitto}/bin/mosquitto_pub',
                        '-h', '${cfg.brokerHost}',
                        '-p', '${toString cfg.brokerPort}',
                        '-t', '${cfg.topicPrefix}/bme280/humidity',
                        '-m', f'{data.humidity:.2f}',
                        '-u', '${cfg.username}',
                        '-P', '${cfg.password}',
                        '-i', '${cfg.clientId}',
                        '-r'
                    ])
                    
                    subprocess.run([
                        '${pkgs.mosquitto}/bin/mosquitto_pub',
                        '-h', '${cfg.brokerHost}',
                        '-p', '${toString cfg.brokerPort}',
                        '-t', '${cfg.topicPrefix}/bme280/pressure',
                        '-m', f'{data.pressure:.2f}',
                        '-u', '${cfg.username}',
                        '-P', '${cfg.password}',
                        '-i', '${cfg.clientId}',
                        '-r'
                    ])
                except Exception as e:
                    print(f'Error reading BME280: {e}')
                " || echo "Failed to read BME280 sensor"
              fi
            fi
          }
          
          # Function to read 1-Wire sensors
          read_onewire_sensors() {
            if ${toString cfg.enableOneWire}; then
              echo "Reading 1-Wire sensors..."
              
              # Check for DS18B20 temperature sensors
              if [ -d /sys/bus/w1/devices ]; then
                for sensor in /sys/bus/w1/devices/28-*/temperature; do
                  if [ -f "$sensor" ]; then
                    # Read temperature
                    temp=$(cat "$sensor")
                    temp=$(echo "scale=2; $temp / 1000" | bc)
                    
                    # Get sensor ID
                    sensor_id=$(basename $(dirname "$sensor"))
                    
                    # Publish to MQTT
                    ${pkgs.mosquitto}/bin/mosquitto_pub -h "$BROKER_HOST" -p "$BROKER_PORT" \
                      -t "$TOPIC_PREFIX/onewire/$sensor_id" -m "$temp" \
                      -u "$USERNAME" -P "$PASSWORD" \
                      -i "$CLIENT_ID" -r
                  fi
                done
              fi
            fi
          }
          
          # Function to read system sensors
          read_system_sensors() {
            echo "Reading system sensors..."
            
            # CPU temperature
            if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
              temp=$(cat /sys/class/thermal/thermal_zone0/temp)
              temp=$(echo "scale=2; $temp / 1000" | bc)
              
              ${pkgs.mosquitto}/bin/mosquitto_pub -h "$BROKER_HOST" -p "$BROKER_PORT" \
                -t "$TOPIC_PREFIX/system/cpu_temperature" -m "$temp" \
                -u "$USERNAME" -P "$PASSWORD" \
                -i "$CLIENT_ID" -r
            fi
            
            # CPU usage
            cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
            
            ${pkgs.mosquitto}/bin/mosquitto_pub -h "$BROKER_HOST" -p "$BROKER_PORT" \
              -t "$TOPIC_PREFIX/system/cpu_usage" -m "$cpu_usage" \
              -u "$USERNAME" -P "$PASSWORD" \
              -i "$CLIENT_ID" -r
            
            # Memory usage
            mem_usage=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
            
            ${pkgs.mosquitto}/bin/mosquitto_pub -h "$BROKER_HOST" -p "$BROKER_PORT" \
              -t "$TOPIC_PREFIX/system/memory_usage" -m "$mem_usage" \
              -u "$USERNAME" -P "$PASSWORD" \
              -i "$CLIENT_ID" -r
            
            # Disk usage
            disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
            
            ${pkgs.mosquitto}/bin/mosquitto_pub -h "$BROKER_HOST" -p "$BROKER_PORT" \
              -t "$TOPIC_PREFIX/system/disk_usage" -m "$disk_usage" \
              -u "$USERNAME" -P "$PASSWORD" \
              -i "$CLIENT_ID" -r
          }
          
          # Main loop
          while true; do
            # Read all sensors
            read_gpio_sensors
            read_i2c_sensors
            read_onewire_sensors
            read_system_sensors
            
            # Wait for next interval
            sleep $SENSOR_INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # MQTT relay user
    users.users.mqtt-relay = {
      isSystemUser = true;
      group = "mqtt-relay";
      description = "MQTT relay service user";
      extraGroups = [ "gpio" "i2c" ];
    };
    
    users.groups.mqtt-relay = {};
    
    # MQTT tools
    environment.systemPackages = with pkgs; [
      mosquitto
      python3
      python3Packages.smbus2
      python3Packages.bme280
      i2c-tools
      
      # Helper scripts
      (writeScriptBin "mqtt-status" ''
        #!/bin/bash
        echo "Starfleet OS MQTT Relay Status"
        echo "============================"
        
        echo "MQTT broker:"
        systemctl status mosquitto
        
        echo ""
        echo "MQTT relay:"
        systemctl status mqtt-relay
        
        echo ""
        echo "Recent sensor readings:"
        ${mosquitto}/bin/mosquitto_sub -h "${cfg.brokerHost}" -p ${toString cfg.brokerPort} \
          -t "${cfg.topicPrefix}/#" \
          -u "${cfg.username}" -P "${cfg.password}" \
          -v -W 1
      '')
      
      (writeScriptBin "mqtt-publish" ''
        #!/bin/bash
        if [ $# -lt 2 ]; then
          echo "Usage: mqtt-publish <topic> <message>"
          exit 1
        fi
        
        TOPIC=$1
        MESSAGE=$2
        
        echo "Publishing to topic: $TOPIC"
        echo "Message: $MESSAGE"
        
        ${mosquitto}/bin/mosquitto_pub -h "${cfg.brokerHost}" -p ${toString cfg.brokerPort} \
          -t "$TOPIC" -m "$MESSAGE" \
          -u "${cfg.username}" -P "${cfg.password}"
        
        echo "Message published"
      '')
      
      (writeScriptBin "mqtt-subscribe" ''
        #!/bin/bash
        if [ $# -lt 1 ]; then
          echo "Usage: mqtt-subscribe <topic>"
          echo "Example: mqtt-subscribe ${cfg.topicPrefix}/#"
          exit 1
        fi
        
        TOPIC=$1
        
        echo "Subscribing to topic: $TOPIC"
        echo "Press Ctrl+C to exit"
        
        ${mosquitto}/bin/mosquitto_sub -h "${cfg.brokerHost}" -p ${toString cfg.brokerPort} \
          -t "$TOPIC" \
          -u "${cfg.username}" -P "${cfg.password}" \
          -v
      '')
    ];
  };
}