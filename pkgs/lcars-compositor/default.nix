{ lib, stdenv, pkg-config, cairo, pango, gdk-pixbuf, glib, gtk4, wayland, wayland-protocols, meson, ninja, lcarsColors }:

stdenv.mkDerivation rec {
  pname = "lcars-compositor";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
  ];

  buildInputs = [
    cairo
    pango
    gdk-pixbuf
    glib
    gtk4
    wayland
    wayland-protocols
  ];

  mesonFlags = [
    "-Dcolor_primary=${lcarsColors.starfleet.primary}"
    "-Dcolor_secondary=${lcarsColors.starfleet.secondary}"
    "-Dcolor_accent=${lcarsColors.starfleet.accent}"
    "-Dcolor_background=${lcarsColors.starfleet.background}"
  ];

  meta = with lib; {
    description = "LCARS window compositor for Starfleet OS";
    homepage = "https://starfleet-os.com";
    license = licenses.gpl3;
    maintainers = [ "Starfleet Engineering Corps" ];
    platforms = platforms.linux;
  };
}