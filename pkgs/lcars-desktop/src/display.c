#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "display.h"

struct display_config *display_config_create(const char *resolution, int refresh_rate) {
    struct display_config *config = malloc(sizeof(struct display_config));
    if (!config) {
        return NULL;
    }
    
    config->resolution = strdup(resolution);
    config->refresh_rate = refresh_rate;
    
    if (display_parse_resolution(resolution, &config->width, &config->height) < 0) {
        free(config->resolution);
        free(config);
        return NULL;
    }
    
    return config;
}

void display_config_destroy(struct display_config *config) {
    if (config) {
        free(config->resolution);
        free(config);
    }
}

int display_parse_resolution(const char *resolution, int *width, int *height) {
    if (!resolution || !width || !height) {
        return -1;
    }
    
    char *endptr;
    *width = strtol(resolution, &endptr, 10);
    if (*endptr != 'x' && *endptr != 'X') {
        return -1;
    }
    
    *height = strtol(endptr + 1, NULL, 10);
    if (*width <= 0 || *height <= 0) {
        return -1;
    }
    
    return 0;
}

char **display_get_modes(void) {
    static char *modes[] = {
        "1920x1080",
        "1680x1050",
        "1600x900",
        "1440x900",
        "1366x768",
        "1280x1024",
        "1280x800",
        "1280x720",
        "1024x768",
        "800x600",
        NULL
    };
    
    return modes;
}

int display_set_mode(const char *mode) {
    // This would normally use XRandR or similar to set the mode
    // For now, just validate that the mode is supported
    char **modes = display_get_modes();
    for (int i = 0; modes[i]; i++) {
        if (strcmp(modes[i], mode) == 0) {
            return 0;
        }
    }
    
    return -1;
}