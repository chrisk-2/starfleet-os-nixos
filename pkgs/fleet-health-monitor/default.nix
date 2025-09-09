{ lib, stdenv, fetchFromGitHub, nodejs, nodePackages, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "fleet-health-monitor";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [
    nodejs
    nodePackages.npm
    makeWrapper
  ];

  buildPhase = ''
    export HOME=$PWD
    npm install
    npm run build
  '';

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/fleet-health-monitor

    # Copy built application
    cp -r dist/* $out/share/fleet-health-monitor/
    cp -r node_modules $out/share/fleet-health-monitor/
    cp package.json $out/share/fleet-health-monitor/

    # Create wrapper script
    makeWrapper ${nodejs}/bin/node $out/bin/fleet-health-monitor \
      --add-flags "$out/share/fleet-health-monitor/server.js"
  '';

  meta = with lib; {
    description = "Fleet health monitoring dashboard for Starfleet OS";
    homepage = "https://starfleet-os.com";
    license = licenses.gpl3;
    maintainers = [ "Starfleet Engineering Corps" ];
    platforms = platforms.linux;
  };
}