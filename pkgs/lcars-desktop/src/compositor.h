#ifndef COMPOSITOR_H
#define COMPOSITOR_H

#include <wayland-server.h>

/**
 * Wayland registry listener
 */
extern const struct wl_registry_listener registry_listener;

/**
 * Initialize the compositor
 * 
 * @param display Wayland display
 * @return 0 on success, -1 on failure
 */
int compositor_init(struct wl_display *display);

/**
 * Create a new surface
 * 
 * @param compositor Wayland compositor
 * @return New Wayland surface
 */
struct wl_surface *compositor_create_surface(struct wl_compositor *compositor);

/**
 * Create a new shell surface
 * 
 * @param shell Wayland shell
 * @param surface Wayland surface
 * @return New Wayland shell surface
 */
struct wl_shell_surface *compositor_create_shell_surface(struct wl_shell *shell, 
                                                       struct wl_surface *surface);

/**
 * Set the shell surface title
 * 
 * @param shell_surface Wayland shell surface
 * @param title Title to set
 */
void compositor_set_title(struct wl_shell_surface *shell_surface, const char *title);

/**
 * Set the shell surface to fullscreen
 * 
 * @param shell_surface Wayland shell surface
 * @param output Wayland output
 */
void compositor_set_fullscreen(struct wl_shell_surface *shell_surface, 
                             struct wl_output *output);

/**
 * Handle input events
 * 
 * @param display Wayland display
 */
void compositor_handle_input(struct wl_display *display);

#endif /* COMPOSITOR_H */