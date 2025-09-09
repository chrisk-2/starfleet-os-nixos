#ifndef INPUT_H
#define INPUT_H

#include <wayland-client.h>

/**
 * Initialize input handling
 * 
 * @param seat Wayland seat
 * @param data User data (typically the LCARS state)
 * @return 0 on success, -1 on failure
 */
int input_init(struct wl_seat *seat, void *data);

#endif /* INPUT_H */