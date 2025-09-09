#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include <wayland-egl.h>

#include "compositor.h"

// Global registry listener
static void registry_handle_global(void *data, struct wl_registry *registry,
                                 uint32_t id, const char *interface, uint32_t version) {
    struct lcars_state *state = data;
    
    if (strcmp(interface, "wl_compositor") == 0) {
        state->compositor = wl_registry_bind(registry, id, &wl_compositor_interface, 1);
    } else if (strcmp(interface, "wl_shell") == 0) {
        state->shell = wl_registry_bind(registry, id, &wl_shell_interface, 1);
    } else if (strcmp(interface, "wl_seat") == 0) {
        state->seat = wl_registry_bind(registry, id, &wl_seat_interface, 1);
    } else if (strcmp(interface, "wl_output") == 0) {
        state->output = wl_registry_bind(registry, id, &wl_output_interface, 1);
    }
}

static void registry_handle_global_remove(void *data, struct wl_registry *registry,
                                        uint32_t name) {
    // Handle global removal
}

const struct wl_registry_listener registry_listener = {
    registry_handle_global,
    registry_handle_global_remove
};

int compositor_init(struct wl_display *display) {
    if (!display) {
        return -1;
    }
    
    return 0;
}

struct wl_surface *compositor_create_surface(struct wl_compositor *compositor) {
    if (!compositor) {
        return NULL;
    }
    
    return wl_compositor_create_surface(compositor);
}

struct wl_shell_surface *compositor_create_shell_surface(struct wl_shell *shell, 
                                                       struct wl_surface *surface) {
    if (!shell || !surface) {
        return NULL;
    }
    
    return wl_shell_get_shell_surface(shell, surface);
}

void compositor_set_title(struct wl_shell_surface *shell_surface, const char *title) {
    if (!shell_surface || !title) {
        return;
    }
    
    wl_shell_surface_set_title(shell_surface, title);
}

void compositor_set_fullscreen(struct wl_shell_surface *shell_surface, 
                             struct wl_output *output) {
    if (!shell_surface) {
        return;
    }
    
    wl_shell_surface_set_fullscreen(shell_surface, 
                                  WL_SHELL_SURFACE_FULLSCREEN_METHOD_DEFAULT,
                                  0, output);
}

void compositor_handle_input(struct wl_display *display) {
    if (!display) {
        return;
    }
    
    wl_display_dispatch(display);
}