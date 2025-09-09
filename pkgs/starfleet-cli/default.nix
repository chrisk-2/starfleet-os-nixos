{ lib, stdenv, fetchFromGitHub, rustPlatform, pkg-config, openssl, nodeRoles }:

rustPlatform.buildRustPackage rec {
  pname = "starfleet-cli";
  version = "1.0.0";

  src = ./.;

  cargoSha256 = lib.fakeSha256;

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  # Generate configuration from nodeRoles
  postPatch = ''
    mkdir -p $out/etc/starfleet
    cat > $out/etc/starfleet/node-roles.json << EOF
    ${builtins.toJSON nodeRoles}
    EOF
  '';

  meta = with lib; {
    description = "Command-line interface for Starfleet OS";
    homepage = "https://starfleet-os.com";
    license = licenses.gpl3;
    maintainers = [ "Starfleet Engineering Corps" ];
    platforms = platforms.linux;
  };
}