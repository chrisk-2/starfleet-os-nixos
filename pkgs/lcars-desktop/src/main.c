#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <wayland-client.h>
#include <wayland-cursor.h>
#include <wayland-egl.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <cairo/cairo.h>
#include <pango/pango.h>
#include <pango/pangocairo.h>
#include <gtk/gtk.h>

#include "config.h"
#include "lcars.h"
#include "display.h"
#include "compositor.h"
#include "theme.h"

// Global LCARS state
static struct lcars_state {
    struct wl_display *display;
    struct wl_registry *registry;
    struct wl_compositor *compositor;
    struct wl_shell *shell;
    struct wl_seat *seat;
    struct wl_pointer *pointer;
    struct wl_keyboard *keyboard;
    struct wl_output *output;
    
    struct wl_surface *surface;
    struct wl_shell_surface *shell_surface;
    struct wl_egl_window *egl_window;
    EGLDisplay egl_display;
    EGLContext egl_context;
    EGLSurface egl_surface;
    
    struct theme_data *theme;
    struct display_config *config;
    
    int running;
    int width;
    int height;
} state;

// Signal handler for clean shutdown
static void signal_handler(int signum) {
    printf("Received signal %d, shutting down...\n", signum);
    state.running = 0;
}

// Initialize LCARS display
static int lcars_init_display(void) {
    state.display = wl_display_connect(NULL);
    if (!state.display) {
        fprintf(stderr, "Failed to connect to Wayland display\n");
        return -1;
    }
    
    state.registry = wl_display_get_registry(state.display);
    wl_registry_add_listener(state.registry, &registry_listener, &state);
    
    wl_display_roundtrip(state.display);
    
    if (!state.compositor || !state.shell) {
        fprintf(stderr, "Failed to bind required interfaces\n");
        return -1;
    }
    
    return 0;
}

// Initialize EGL context
static int lcars_init_egl(void) {
    static const EGLint config_attribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_NONE
    };
    
    static const EGLint context_attribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE
    };
    
    EGLint major, minor;
    EGLConfig egl_config;
    EGLint num_configs;
    
    state.egl_display = eglGetDisplay(state.display);
    if (state.egl_display == EGL_NO_DISPLAY) {
        fprintf(stderr, "Failed to get EGL display\n");
        return -1;
    }
    
    if (!eglInitialize(state.egl_display, &major, &minor)) {
        fprintf(stderr, "Failed to initialize EGL\n");
        return -1;
    }
    
    if (!eglChooseConfig(state.egl_display, config_attribs, 
                        &egl_config, 1, &num_configs) || num_configs == 0) {
        fprintf(stderr, "Failed to choose EGL config\n");
        return -1;
    }
    
    state.egl_context = eglCreateContext(state.egl_display, egl_config,
                                       EGL_NO_CONTEXT, context_attribs);
    if (state.egl_context == EGL_NO_CONTEXT) {
        fprintf(stderr, "Failed to create EGL context\n");
        return -1;
    }
    
    return 0;
}

// Main rendering loop
static void lcars_render_frame(void) {
    cairo_surface_t *surface = cairo_image_surface_create(
        CAIRO_FORMAT_ARGB32, state.width, state.height);
    cairo_t *cr = cairo_create(surface);
    
    // Clear background
    cairo_set_source_rgba(cr, 
        theme_get_red(state.theme, "background"),
        theme_get_green(state.theme, "background"),
        theme_get_blue(state.theme, "background"),
        theme_get_alpha(state.theme, "background"));
    cairo_paint(cr);
    
    // Draw LCARS interface
    lcars_draw_main_interface(cr, state.width, state.height, state.theme);
    
    // Render to EGL surface
    glViewport(0, 0, state.width, state.height);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Upload cairo surface to OpenGL texture
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, state.width, state.height,
                 0, GL_BGRA, GL_UNSIGNED_BYTE,
                 cairo_image_surface_get_data(surface));
    
    // Draw textured quad
    glEnable(GL_TEXTURE_2D);
    glBegin(GL_QUADS);
    glTexCoord2f(0.0f, 0.0f); glVertex2f(-1.0f, -1.0f);
    glTexCoord2f(1.0f, 0.0f); glVertex2f(1.0f, -1.0f);
    glTexCoord2f(1.0f, 1.0f); glVertex2f(1.0f, 1.0f);
    glTexCoord2f(0.0f, 1.0f); glVertex2f(-1.0f, 1.0f);
    glEnd();
    
    eglSwapBuffers(state.egl_display, state.egl_surface);
    
    cairo_destroy(cr);
    cairo_surface_destroy(surface);
    glDeleteTextures(1, &texture);
}

// Main event loop
static void lcars_run(void) {
    state.running = 1;
    
    while (state.running && wl_display_dispatch(state.display) != -1) {
        lcars_render_frame();
    }
}

// Cleanup
static void lcars_cleanup(void) {
    if (state.egl_surface) eglDestroySurface(state.egl_display, state.egl_surface);
    if (state.egl_context) eglDestroyContext(state.egl_display, state.egl_context);
    if (state.egl_display) eglTerminate(state.egl_display);
    
    if (state.egl_window) wl_egl_window_destroy(state.egl_window);
    if (state.shell_surface) wl_shell_surface_destroy(state.shell_surface);
    if (state.surface) wl_surface_destroy(state.surface);
    
    if (state.pointer) wl_pointer_destroy(state.pointer);
    if (state.keyboard) wl_keyboard_destroy(state.keyboard);
    if (state.seat) wl_seat_destroy(state.seat);
    
    if (state.shell) wl_shell_destroy(state.shell);
    if (state.compositor) wl_compositor_destroy(state.compositor);
    if (state.registry) wl_registry_destroy(state.registry);
    if (state.display) wl_display_disconnect(state.display);
    
    theme_destroy(state.theme);
    display_config_destroy(state.config);
}

int main(int argc, char *argv[]) {
    // Parse command line arguments
    const char *mode = "starfleet";
    const char *resolution = "1920x1080";
    int refresh_rate = 60;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--mode") == 0 && i + 1 < argc) {
            mode = argv[++i];
        } else if (strcmp(argv[i], "--resolution") == 0 && i + 1 < argc) {
            resolution = argv[++i];
        } else if (strcmp(argv[i], "--refresh") == 0 && i + 1 < argc) {
            refresh_rate = atoi(argv[++i]);
        }
    }
    
    printf("Starting Starfleet OS LCARS Display Server\n");
    printf("Mode: %s\n", mode);
    printf("Resolution: %s\n", resolution);
    printf("Refresh Rate: %d Hz\n", refresh_rate);
    
    // Initialize signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Initialize components
    state.theme = theme_create(mode);
    state.config = display_config_create(resolution, refresh_rate);
    
    if (lcars_init_display() < 0) {
        return 1;
    }
    
    if (lcars_init_egl() < 0) {
        return 1;
    }
    
    // Run main loop
    lcars_run();
    
    // Cleanup
    lcars_cleanup();
    
    printf("LCARS Display Server shutdown complete\n");
    return 0;
}