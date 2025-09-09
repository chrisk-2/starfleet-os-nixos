{ lib, stdenv, fetchFromGitHub, python3Packages, usbutils, pciutils, dmidecode, lshw }:

stdenv.mkDerivation rec {
  pname = "assimilation-tools";
  version = "1.0.0";

  src = ./.;

  buildInputs = [
    python3Packages.python
    python3Packages.pyusb
    python3Packages.pyyaml
    python3Packages.requests
    usbutils
    pciutils
    dmidecode
    lshw
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/assimilation-tools

    # Install scripts
    cp -r scripts/* $out/bin/
    chmod +x $out/bin/*

    # Install data files
    cp -r data/* $out/share/assimilation-tools/

    # Create wrapper scripts
    cat > $out/bin/usb-assimilate << EOF
    #!/bin/sh
    exec ${python3Packages.python}/bin/python $out/bin/usb_assimilate.py "\$@"
    EOF
    chmod +x $out/bin/usb-assimilate

    cat > $out/bin/hardware-scan << EOF
    #!/bin/sh
    exec ${python3Packages.python}/bin/python $out/bin/hardware_scan.py "\$@"
    EOF
    chmod +x $out/bin/hardware-scan
  '';

  meta = with lib; {
    description = "Hardware assimilation tools for Starfleet OS";
    homepage = "https://starfleet-os.com";
    license = licenses.gpl3;
    maintainers = [ "Starfleet Engineering Corps" ];
    platforms = platforms.linux;
  };
}