#ifndef PROTOCOLS_H
#define PROTOCOLS_H

#include <wayland-client.h>

/**
 * Initialize shell surface
 * 
 * @param shell_surface Wayland shell surface
 * @param data User data (typically the LCARS state)
 * @return 0 on success, -1 on failure
 */
int shell_surface_init(struct wl_shell_surface *shell_surface, void *data);

/**
 * Initialize output
 * 
 * @param output Wayland output
 * @param data User data (typically the LCARS state)
 * @return 0 on success, -1 on failure
 */
int output_init(struct wl_output *output, void *data);

#endif /* PROTOCOLS_H */