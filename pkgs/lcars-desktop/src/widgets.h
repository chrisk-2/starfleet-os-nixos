#ifndef WIDGETS_H
#define WIDGETS_H

#include <cairo/cairo.h>
#include "theme.h"

// Forward declarations
typedef struct lcars_button_t lcars_button_t;
typedef struct lcars_panel_t lcars_panel_t;
typedef struct lcars_text_t lcars_text_t;
typedef struct lcars_status_bar_t lcars_status_bar_t;

/**
 * Create a new LCARS button
 * 
 * @param x X position
 * @param y Y position
 * @param width Width of the button
 * @param height Height of the button
 * @param radius Corner radius
 * @param label Button label text
 * @param color_key Color key to use from theme
 * @return Newly allocated button
 */
lcars_button_t *lcars_button_create(int x, int y, int width, int height, int radius,
                                  const char *label, const char *color_key);

/**
 * Destroy an LCARS button
 * 
 * @param button Button to destroy
 */
void lcars_button_destroy(lcars_button_t *button);

/**
 * Set button callback
 * 
 * @param button Button to set callback for
 * @param callback Callback function
 * @param user_data User data to pass to callback
 */
void lcars_button_set_callback(lcars_button_t *button, void (*callback)(void *data), void *user_data);

/**
 * Check if point is inside button
 * 
 * @param button Button to check
 * @param x X position
 * @param y Y position
 * @return 1 if point is inside button, 0 otherwise
 */
int lcars_button_contains(lcars_button_t *button, int x, int y);

/**
 * Handle button click
 * 
 * @param button Button to click
 */
void lcars_button_click(lcars_button_t *button);

/**
 * Create a new LCARS panel
 * 
 * @param x X position
 * @param y Y position
 * @param width Width of the panel
 * @param height Height of the panel
 * @param color_key Color key to use from theme
 * @param style Panel style (0 = rectangular, 1 = rounded, 2 = elbow)
 * @return Newly allocated panel
 */
lcars_panel_t *lcars_panel_create(int x, int y, int width, int height,
                                const char *color_key, int style);

/**
 * Destroy an LCARS panel
 * 
 * @param panel Panel to destroy
 */
void lcars_panel_destroy(lcars_panel_t *panel);

/**
 * Create a new LCARS text widget
 * 
 * @param x X position
 * @param y Y position
 * @param text Text to display
 * @param size Font size
 * @param color_key Color key to use from theme
 * @param alignment Text alignment (0 = left, 1 = center, 2 = right)
 * @return Newly allocated text widget
 */
lcars_text_t *lcars_text_create(int x, int y, const char *text, int size,
                              const char *color_key, int alignment);

/**
 * Destroy an LCARS text widget
 * 
 * @param text_widget Text widget to destroy
 */
void lcars_text_destroy(lcars_text_t *text_widget);

/**
 * Create a new LCARS status bar
 * 
 * @param x X position
 * @param y Y position
 * @param width Width of the bar
 * @param height Height of the bar
 * @param value Value between 0.0 and 1.0
 * @param color_key Color key to use from theme
 * @param label Optional label text
 * @return Newly allocated status bar
 */
lcars_status_bar_t *lcars_status_bar_create(int x, int y, int width, int height,
                                         float value, const char *color_key,
                                         const char *label);

/**
 * Destroy an LCARS status bar
 * 
 * @param status_bar Status bar to destroy
 */
void lcars_status_bar_destroy(lcars_status_bar_t *status_bar);

/**
 * Set status bar value
 * 
 * @param status_bar Status bar to update
 * @param value Value between 0.0 and 1.0
 */
void lcars_status_bar_set_value(lcars_status_bar_t *status_bar, float value);

#endif /* WIDGETS_H */