#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "theme.h"
#include "config.h"

// Convert hex color to RGB components
static int hex_to_rgb(const char *hex, double *r, double *g, double *b, double *a) {
    if (!hex || !r || !g || !b || !a) {
        return -1;
    }
    
    // Skip leading '#' if present
    if (hex[0] == '#') {
        hex++;
    }
    
    unsigned int rgb;
    if (sscanf(hex, "%x", &rgb) != 1) {
        return -1;
    }
    
    *r = ((rgb >> 16) & 0xFF) / 255.0;
    *g = ((rgb >> 8) & 0xFF) / 255.0;
    *b = (rgb & 0xFF) / 255.0;
    *a = 1.0;
    
    return 0;
}

struct theme_data *theme_create(const char *mode) {
    struct theme_data *theme = malloc(sizeof(struct theme_data));
    if (!theme) {
        return NULL;
    }
    
    theme->mode = strdup(mode);
    
    // Set default colors based on mode
    if (strcmp(mode, "starfleet") == 0) {
        theme->primary = strdup(LCARS_COLOR_PRIMARY);
        theme->secondary = strdup(LCARS_COLOR_SECONDARY);
        theme->accent = strdup(LCARS_COLOR_ACCENT);
        theme->background = strdup(LCARS_COLOR_BACKGROUND);
        theme->text = strdup("#FFFFFF");
        theme->warning = strdup("#FFCC99");
        theme->danger = strdup("#CC6666");
    } else if (strcmp(mode, "section31") == 0) {
        theme->primary = strdup("#333333");
        theme->secondary = strdup("#1a1a1a");
        theme->accent = strdup("#666666");
        theme->background = strdup("#000000");
        theme->text = strdup("#cccccc");
        theme->warning = strdup("#990000");
        theme->danger = strdup("#ff0000");
    } else if (strcmp(mode, "borg") == 0) {
        theme->primary = strdup("#00FF00");
        theme->secondary = strdup("#008800");
        theme->accent = strdup("#004400");
        theme->background = strdup("#000000");
        theme->text = strdup("#00FF00");
        theme->warning = strdup("#FFFF00");
        theme->danger = strdup("#FF0000");
    } else if (strcmp(mode, "terran") == 0) {
        theme->primary = strdup("#FFD700");
        theme->secondary = strdup("#8B4513");
        theme->accent = strdup("#FF6347");
        theme->background = strdup("#000000");
        theme->text = strdup("#FFD700");
        theme->warning = strdup("#FF4500");
        theme->danger = strdup("#DC143C");
    } else if (strcmp(mode, "holodeck") == 0) {
        theme->primary = strdup("#00BFFF");
        theme->secondary = strdup("#87CEEB");
        theme->accent = strdup("#B0E0E6");
        theme->background = strdup("#001133");
        theme->text = strdup("#FFFFFF");
        theme->warning = strdup("#FFD700");
        theme->danger = strdup("#FF6347");
    } else {
        // Default to starfleet
        theme->primary = strdup(LCARS_COLOR_PRIMARY);
        theme->secondary = strdup(LCARS_COLOR_SECONDARY);
        theme->accent = strdup(LCARS_COLOR_ACCENT);
        theme->background = strdup(LCARS_COLOR_BACKGROUND);
        theme->text = strdup("#FFFFFF");
        theme->warning = strdup("#FFCC99");
        theme->danger = strdup("#CC6666");
    }
    
    return theme;
}

void theme_destroy(struct theme_data *theme) {
    if (theme) {
        free(theme->mode);
        free(theme->primary);
        free(theme->secondary);
        free(theme->accent);
        free(theme->background);
        free(theme->text);
        free(theme->warning);
        free(theme->danger);
        free(theme);
    }
}

double theme_get_red(struct theme_data *theme, const char *color_key) {
    double r, g, b, a;
    const char *color = theme_get_color(theme, color_key);
    if (hex_to_rgb(color, &r, &g, &b, &a) < 0) {
        return 0.0;
    }
    return r;
}

double theme_get_green(struct theme_data *theme, const char *color_key) {
    double r, g, b, a;
    const char *color = theme_get_color(theme, color_key);
    if (hex_to_rgb(color, &r, &g, &b, &a) < 0) {
        return 0.0;
    }
    return g;
}

double theme_get_blue(struct theme_data *theme, const char *color_key) {
    double r, g, b, a;
    const char *color = theme_get_color(theme, color_key);
    if (hex_to_rgb(color, &r, &g, &b, &a) < 0) {
        return 0.0;
    }
    return b;
}

double theme_get_alpha(struct theme_data *theme, const char *color_key) {
    double r, g, b, a;
    const char *color = theme_get_color(theme, color_key);
    if (hex_to_rgb(color, &r, &g, &b, &a) < 0) {
        return 1.0;
    }
    return a;
}

const char *theme_get_color(struct theme_data *theme, const char *color_key) {
    if (!theme || !color_key) {
        return "#000000";
    }
    
    if (strcmp(color_key, "primary") == 0) {
        return theme->primary;
    } else if (strcmp(color_key, "secondary") == 0) {
        return theme->secondary;
    } else if (strcmp(color_key, "accent") == 0) {
        return theme->accent;
    } else if (strcmp(color_key, "background") == 0) {
        return theme->background;
    } else if (strcmp(color_key, "text") == 0) {
        return theme->text;
    } else if (strcmp(color_key, "warning") == 0) {
        return theme->warning;
    } else if (strcmp(color_key, "danger") == 0) {
        return theme->danger;
    }
    
    return "#000000";
}

int theme_set_mode(struct theme_data *theme, const char *mode) {
    if (!theme || !mode) {
        return -1;
    }
    
    // Free old theme data
    free(theme->mode);
    free(theme->primary);
    free(theme->secondary);
    free(theme->accent);
    free(theme->background);
    free(theme->text);
    free(theme->warning);
    free(theme->danger);
    
    // Create new theme with the specified mode
    struct theme_data *new_theme = theme_create(mode);
    if (!new_theme) {
        return -1;
    }
    
    // Copy new theme data
    theme->mode = new_theme->mode;
    theme->primary = new_theme->primary;
    theme->secondary = new_theme->secondary;
    theme->accent = new_theme->accent;
    theme->background = new_theme->background;
    theme->text = new_theme->text;
    theme->warning = new_theme->warning;
    theme->danger = new_theme->danger;
    
    // Free the temporary theme structure (but not its data)
    free(new_theme);
    
    return 0;
}