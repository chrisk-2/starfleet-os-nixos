{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ai-helpers;
in
{
  options.services.ai-helpers = {
    enable = mkEnableOption "Starfleet OS AI Helpers";
    
    enableLocalModels = mkOption {
      type = types.bool;
      default = true;
      description = "Enable local AI models";
    };
    
    enableVoiceCommands = mkOption {
      type = types.bool;
      default = true;
      description = "Enable voice command recognition";
    };
    
    enableComputerResponses = mkOption {
      type = types.bool;
      default = true;
      description = "Enable computer voice responses";
    };
    
    wakeWord = mkOption {
      type = types.str;
      default = "Computer";
      description = "Wake word for voice commands";
    };
  };

  config = mkIf cfg.enable {
    # AI model service
    systemd.services.ai-model-server = mkIf cfg.enableLocalModels {
      description = "Starfleet OS AI Model Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.python3Packages.llama-cpp-python}/bin/python -m llama_cpp.server --model /var/lib/ai-models/starfleet-assistant.gguf --n_ctx 4096";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Voice command service
    systemd.services.voice-command = mkIf cfg.enableVoiceCommands {
      description = "Starfleet OS Voice Command Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "sound.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.writeShellScript "voice-command-service" ''
          #!/bin/bash
          
          WAKE_WORD="${cfg.wakeWord}"
          
          echo "Starting Starfleet OS Voice Command Service"
          echo "Wake word: $WAKE_WORD"
          
          # Use porcupine for wake word detection
          ${pkgs.python3}/bin/python3 -c "
          import pvporcupine
          import pyaudio
          import struct
          import subprocess
          
          # Initialize wake word detection
          porcupine = pvporcupine.create(keywords=['${cfg.wakeWord}'])
          pa = pyaudio.PyAudio()
          
          # Open audio stream
          audio_stream = pa.open(
              rate=porcupine.sample_rate,
              channels=1,
              format=pyaudio.paInt16,
              input=True,
              frames_per_buffer=porcupine.frame_length
          )
          
          print('Listening for wake word...')
          
          try:
              while True:
                  pcm = audio_stream.read(porcupine.frame_length)
                  pcm = struct.unpack_from('h' * porcupine.frame_length, pcm)
                  
                  keyword_index = porcupine.process(pcm)
                  if keyword_index >= 0:
                      print('Wake word detected!')
                      
                      # Play acknowledgment sound
                      subprocess.run(['${pkgs.sox}/bin/play', '-q', '/etc/starfleet/sounds/acknowledge.wav'])
                      
                      # Start voice recognition
                      subprocess.run(['${pkgs.sox}/bin/rec', '-q', '/tmp/command.wav', 'silence', '1', '0.1', '3%', '1', '3.0', '3%'])
                      
                      # Process command with whisper
                      result = subprocess.run(
                          ['${pkgs.openai-whisper}/bin/whisper', '/tmp/command.wav', '--model', 'tiny', '--output_format', 'txt'],
                          capture_output=True,
                          text=True
                      )
                      
                      command = result.stdout.strip()
                      print(f'Command: {command}')
                      
                      # Send command to AI helper
                      response = subprocess.run(
                          ['curl', '-s', 'http://localhost:8000/v1/completions', 
                           '-H', 'Content-Type: application/json',
                           '-d', '{&quot;prompt&quot;: &quot;' + command + '&quot;, &quot;max_tokens&quot;: 100}'],
                          capture_output=True,
                          text=True
                      )
                      
                      # Speak response
                      subprocess.run(['${pkgs.espeak}/bin/espeak', response.stdout])
          finally:
              audio_stream.close()
              pa.terminate()
              porcupine.delete()
          "
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Computer response service
    systemd.services.computer-response = mkIf cfg.enableComputerResponses {
      description = "Starfleet OS Computer Response Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "sound.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.writeShellScript "computer-response-service" ''
          #!/bin/bash
          
          echo "Starting Starfleet OS Computer Response Service"
          
          # Create response server
          ${pkgs.python3}/bin/python3 -c "
          from http.server import HTTPServer, BaseHTTPRequestHandler
          import json
          import subprocess
          import os
          
          class ResponseHandler(BaseHTTPRequestHandler):
              def do_POST(self):
                  content_length = int(self.headers['Content-Length'])
                  post_data = self.rfile.read(content_length)
                  data = json.loads(post_data.decode('utf-8'))
                  
                  # Get the message to speak
                  message = data.get('message', '')
                  
                  # Use espeak for text-to-speech
                  subprocess.run(['${pkgs.espeak}/bin/espeak', message])
                  
                  # Send response
                  self.send_response(200)
                  self.send_header('Content-type', 'application/json')
                  self.end_headers()
                  self.wfile.write(json.dumps({'status': 'success'}).encode())
          
          # Start server
          server = HTTPServer(('localhost', 8765), ResponseHandler)
          print('Starting computer response server on port 8765')
          server.serve_forever()
          "
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # AI helper tools
    environment.systemPackages = with pkgs; [
      # AI tools
      python3
      python3Packages.llama-cpp-python
      python3Packages.pyaudio
      python3Packages.porcupine
      openai-whisper
      espeak
      sox
      
      # Helper scripts
      (writeScriptBin "computer-say" ''
        #!/bin/bash
        if [ $# -eq 0 ]; then
          echo "Usage: computer-say <message>"
          exit 1
        fi
        
        MESSAGE="$*"
        
        curl -s -X POST -H "Content-Type: application/json" \
          -d "{&quot;message&quot;: &quot;$MESSAGE&quot;}" \
          http://localhost:8765
      '')
      
      (writeScriptBin "ai-query" ''
        #!/bin/bash
        if [ $# -eq 0 ]; then
          echo "Usage: ai-query <question>"
          exit 1
        fi
        
        QUERY="$*"
        
        curl -s "http://localhost:8000/v1/completions" \
          -H "Content-Type: application/json" \
          -d "{&quot;prompt&quot;: &quot;$QUERY&quot;, &quot;max_tokens&quot;: 500}" | jq -r '.choices[0].text'
      '')
    ];
    
    # Create sound directory
    systemd.tmpfiles.rules = [
      "d /etc/starfleet/sounds 0755 starfleet starfleet -"
    ];
    
    # Create model directory
    systemd.tmpfiles.rules = [
      "d /var/lib/ai-models 0755 starfleet starfleet -"
    ];
  };
}