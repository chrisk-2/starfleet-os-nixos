#ifndef LCARS_H
#define LCARS_H

#include <cairo/cairo.h>
#include "theme.h"

/**
 * Draw the main LCARS interface
 * 
 * @param cr Cairo context to draw on
 * @param width Width of the surface
 * @param height Height of the surface
 * @param theme Current theme data
 */
void lcars_draw_main_interface(cairo_t *cr, int width, int height, struct theme_data *theme);

/**
 * Draw an LCARS panel
 * 
 * @param cr Cairo context to draw on
 * @param x X position
 * @param y Y position
 * @param width Width of the panel
 * @param height Height of the panel
 * @param theme Current theme data
 * @param color_key Color key to use from theme
 */
void lcars_draw_panel(cairo_t *cr, int x, int y, int width, int height, 
                     struct theme_data *theme, const char *color_key);

/**
 * Draw an LCARS button
 * 
 * @param cr Cairo context to draw on
 * @param x X position
 * @param y Y position
 * @param width Width of the button
 * @param height Height of the button
 * @param radius Corner radius
 * @param theme Current theme data
 * @param color_key Color key to use from theme
 * @param label Button label text
 */
void lcars_draw_button(cairo_t *cr, int x, int y, int width, int height, int radius,
                      struct theme_data *theme, const char *color_key, const char *label);

/**
 * Draw an LCARS text label
 * 
 * @param cr Cairo context to draw on
 * @param x X position
 * @param y Y position
 * @param theme Current theme data
 * @param color_key Color key to use from theme
 * @param text Text to display
 * @param size Font size
 */
void lcars_draw_text(cairo_t *cr, int x, int y, struct theme_data *theme,
                    const char *color_key, const char *text, int size);

/**
 * Draw an LCARS status bar
 * 
 * @param cr Cairo context to draw on
 * @param x X position
 * @param y Y position
 * @param width Width of the bar
 * @param height Height of the bar
 * @param value Value between 0.0 and 1.0
 * @param theme Current theme data
 * @param color_key Color key to use from theme
 */
void lcars_draw_status_bar(cairo_t *cr, int x, int y, int width, int height, 
                          float value, struct theme_data *theme, const char *color_key);

#endif /* LCARS_H */