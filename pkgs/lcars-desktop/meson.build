project('lcars-desktop', 'c',
  version: '1.0.0',
  default_options: ['warning_level=2', 'c_std=c11'])

# Dependencies
cairo = dependency('cairo')
pango = dependency('pango')
gdk_pixbuf = dependency('gdk-pixbuf-2.0')
glib = dependency('glib-2.0')
gtk = dependency('gtk4')
wayland_client = dependency('wayland-client')
wayland_cursor = dependency('wayland-cursor')
wayland_egl = dependency('wayland-egl')
epoxy = dependency('epoxy')
xkbcommon = dependency('xkbcommon')

# Configuration
conf_data = configuration_data()
conf_data.set_quoted('PACKAGE_NAME', meson.project_name())
conf_data.set_quoted('PACKAGE_VERSION', meson.project_version())
conf_data.set_quoted('LCARS_COLOR_PRIMARY', get_option('color_primary'))
conf_data.set_quoted('LCARS_COLOR_SECONDARY', get_option('color_secondary'))
conf_data.set_quoted('LCARS_COLOR_ACCENT', get_option('color_accent'))
conf_data.set_quoted('LCARS_COLOR_BACKGROUND', get_option('color_background'))

configure_file(
  input: 'config.h.in',
  output: 'config.h',
  configuration: conf_data
)

# Sources
sources = [
  'src/main.c',
  'src/lcars.c',
  'src/widgets.c',
  'src/compositor.c',
  'src/display.c',
  'src/theme.c',
  'src/input.c',
  'src/protocols.c'
]

executable('lcars-display',
  sources,
  dependencies: [
    cairo,
    pango,
    gdk_pixbuf,
    glib,
    gtk,
    wayland_client,
    wayland_cursor,
    wayland_egl,
    epoxy,
    xkbcommon
  ],
  install: true
)

# Install desktop files
install_data('starfleet-lcars.desktop',
  install_dir: join_paths(get_option('datadir'), 'applications')
)