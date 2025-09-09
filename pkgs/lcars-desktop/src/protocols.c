#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>

// Shell surface listener
static void handle_ping(void *data, struct wl_shell_surface *shell_surface,
                      uint32_t serial) {
    wl_shell_surface_pong(shell_surface, serial);
}

static void handle_configure(void *data, struct wl_shell_surface *shell_surface,
                           uint32_t edges, int32_t width, int32_t height) {
    // Handle configure
    struct lcars_state *state = data;
    
    if (width > 0 && height > 0) {
        state->width = width;
        state->height = height;
    }
}

static void handle_popup_done(void *data, struct wl_shell_surface *shell_surface) {
    // Handle popup done
}

static const struct wl_shell_surface_listener shell_surface_listener = {
    handle_ping,
    handle_configure,
    handle_popup_done
};

// Initialize shell surface
int shell_surface_init(struct wl_shell_surface *shell_surface, void *data) {
    if (!shell_surface) {
        return -1;
    }
    
    wl_shell_surface_add_listener(shell_surface, &shell_surface_listener, data);
    return 0;
}

// Output listener
static void output_handle_geometry(void *data, struct wl_output *output,
                                 int32_t x, int32_t y, int32_t physical_width,
                                 int32_t physical_height, int32_t subpixel,
                                 const char *make, const char *model,
                                 int32_t transform) {
    printf("Output: %s %s\n", make, model);
}

static void output_handle_mode(void *data, struct wl_output *output,
                             uint32_t flags, int32_t width, int32_t height,
                             int32_t refresh) {
    if (flags & WL_OUTPUT_MODE_CURRENT) {
        struct lcars_state *state = data;
        state->width = width;
        state->height = height;
        printf("Output mode: %dx%d@%d\n", width, height, refresh / 1000);
    }
}

static void output_handle_done(void *data, struct wl_output *output) {
    // Handle done
}

static void output_handle_scale(void *data, struct wl_output *output,
                              int32_t factor) {
    printf("Output scale: %d\n", factor);
}

static const struct wl_output_listener output_listener = {
    output_handle_geometry,
    output_handle_mode,
    output_handle_done,
    output_handle_scale
};

// Initialize output
int output_init(struct wl_output *output, void *data) {
    if (!output) {
        return -1;
    }
    
    wl_output_add_listener(output, &output_listener, data);
    return 0;
}