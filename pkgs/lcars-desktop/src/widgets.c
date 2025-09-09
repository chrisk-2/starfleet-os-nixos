#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cairo/cairo.h>
#include <pango/pango.h>
#include <pango/pangocairo.h>

#include "lcars.h"
#include "theme.h"

// LCARS Button widget
typedef struct {
    int x;
    int y;
    int width;
    int height;
    int radius;
    char *label;
    char *color_key;
    int state; // 0 = normal, 1 = hover, 2 = pressed
    void (*callback)(void *data);
    void *user_data;
} lcars_button_t;

// LCARS Panel widget
typedef struct {
    int x;
    int y;
    int width;
    int height;
    char *color_key;
    int style; // 0 = rectangular, 1 = rounded, 2 = elbow
} lcars_panel_t;

// LCARS Text widget
typedef struct {
    int x;
    int y;
    char *text;
    int size;
    char *color_key;
    int alignment; // 0 = left, 1 = center, 2 = right
} lcars_text_t;

// LCARS Status Bar widget
typedef struct {
    int x;
    int y;
    int width;
    int height;
    float value;
    char *color_key;
    char *label;
} lcars_status_bar_t;

// Create a new LCARS button
lcars_button_t *lcars_button_create(int x, int y, int width, int height, int radius,
                                  const char *label, const char *color_key) {
    lcars_button_t *button = malloc(sizeof(lcars_button_t));
    if (!button) {
        return NULL;
    }
    
    button->x = x;
    button->y = y;
    button->width = width;
    button->height = height;
    button->radius = radius;
    button->label = strdup(label);
    button->color_key = strdup(color_key);
    button->state = 0;
    button->callback = NULL;
    button->user_data = NULL;
    
    return button;
}

// Destroy an LCARS button
void lcars_button_destroy(lcars_button_t *button) {
    if (button) {
        free(button->label);
        free(button->color_key);
        free(button);
    }
}

// Set button callback
void lcars_button_set_callback(lcars_button_t *button, void (*callback)(void *data), void *user_data) {
    if (button) {
        button->callback = callback;
        button->user_data = user_data;
    }
}

// Check if point is inside button
int lcars_button_contains(lcars_button_t *button, int x, int y) {
    if (!button) {
        return 0;
    }
    
    return x >= button->x && x < button->x + button->width &&
           y >= button->y && y < button->y + button->height;
}

// Handle button click
void lcars_button_click(lcars_button_t *button) {
    if (button && button->callback) {
        button->callback(button->user_data);
    }
}

// Create a new LCARS panel
lcars_panel_t *lcars_panel_create(int x, int y, int width, int height,
                                const char *color_key, int style) {
    lcars_panel_t *panel = malloc(sizeof(lcars_panel_t));
    if (!panel) {
        return NULL;
    }
    
    panel->x = x;
    panel->y = y;
    panel->width = width;
    panel->height = height;
    panel->color_key = strdup(color_key);
    panel->style = style;
    
    return panel;
}

// Destroy an LCARS panel
void lcars_panel_destroy(lcars_panel_t *panel) {
    if (panel) {
        free(panel->color_key);
        free(panel);
    }
}

// Create a new LCARS text widget
lcars_text_t *lcars_text_create(int x, int y, const char *text, int size,
                              const char *color_key, int alignment) {
    lcars_text_t *text_widget = malloc(sizeof(lcars_text_t));
    if (!text_widget) {
        return NULL;
    }
    
    text_widget->x = x;
    text_widget->y = y;
    text_widget->text = strdup(text);
    text_widget->size = size;
    text_widget->color_key = strdup(color_key);
    text_widget->alignment = alignment;
    
    return text_widget;
}

// Destroy an LCARS text widget
void lcars_text_destroy(lcars_text_t *text_widget) {
    if (text_widget) {
        free(text_widget->text);
        free(text_widget->color_key);
        free(text_widget);
    }
}

// Create a new LCARS status bar
lcars_status_bar_t *lcars_status_bar_create(int x, int y, int width, int height,
                                         float value, const char *color_key,
                                         const char *label) {
    lcars_status_bar_t *status_bar = malloc(sizeof(lcars_status_bar_t));
    if (!status_bar) {
        return NULL;
    }
    
    status_bar->x = x;
    status_bar->y = y;
    status_bar->width = width;
    status_bar->height = height;
    status_bar->value = value;
    status_bar->color_key = strdup(color_key);
    status_bar->label = label ? strdup(label) : NULL;
    
    return status_bar;
}

// Destroy an LCARS status bar
void lcars_status_bar_destroy(lcars_status_bar_t *status_bar) {
    if (status_bar) {
        free(status_bar->color_key);
        if (status_bar->label) {
            free(status_bar->label);
        }
        free(status_bar);
    }
}

// Set status bar value
void lcars_status_bar_set_value(lcars_status_bar_t *status_bar, float value) {
    if (status_bar) {
        status_bar->value = value < 0.0f ? 0.0f : (value > 1.0f ? 1.0f : value);
    }
}