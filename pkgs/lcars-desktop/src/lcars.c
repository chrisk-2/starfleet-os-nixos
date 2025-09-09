#include <cairo/cairo.h>
#include <pango/pango.h>
#include <pango/pangocairo.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lcars.h"
#include "theme.h"
#include "config.h"

// Draw a rounded rectangle
static void draw_rounded_rect(cairo_t *cr, double x, double y, double width, double height, double radius) {
    double degrees = M_PI / 180.0;

    cairo_new_sub_path(cr);
    cairo_arc(cr, x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees);
    cairo_arc(cr, x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees);
    cairo_arc(cr, x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees);
    cairo_arc(cr, x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
    cairo_close_path(cr);
}

void lcars_draw_main_interface(cairo_t *cr, int width, int height, struct theme_data *theme) {
    // Draw main frame
    cairo_set_source_rgba(cr, 
        theme_get_red(theme, "primary"),
        theme_get_green(theme, "primary"),
        theme_get_blue(theme, "primary"),
        theme_get_alpha(theme, "primary"));
    
    // Top bar
    cairo_rectangle(cr, 0, 0, width, 60);
    cairo_fill(cr);
    
    // Left sidebar
    cairo_rectangle(cr, 0, 60, 200, height - 60);
    cairo_fill(cr);
    
    // Bottom bar
    cairo_rectangle(cr, 200, height - 60, width - 200, 60);
    cairo_fill(cr);
    
    // Draw secondary elements
    cairo_set_source_rgba(cr, 
        theme_get_red(theme, "secondary"),
        theme_get_green(theme, "secondary"),
        theme_get_blue(theme, "secondary"),
        theme_get_alpha(theme, "secondary"));
    
    // Top right panel
    lcars_draw_panel(cr, width - 300, 80, 280, 200, theme, "secondary");
    
    // Middle panel
    lcars_draw_panel(cr, 220, 80, width - 540, height - 200, theme, "accent");
    
    // Bottom panel
    lcars_draw_panel(cr, 220, height - 100, 300, 40, theme, "secondary");
    
    // Draw buttons
    lcars_draw_button(cr, 20, 80, 160, 40, 10, theme, "accent", "LCARS MAIN");
    lcars_draw_button(cr, 20, 140, 160, 40, 10, theme, "accent", "SYSTEMS");
    lcars_draw_button(cr, 20, 200, 160, 40, 10, theme, "accent", "SENSORS");
    lcars_draw_button(cr, 20, 260, 160, 40, 10, theme, "accent", "TACTICAL");
    lcars_draw_button(cr, 20, 320, 160, 40, 10, theme, "accent", "OPERATIONS");
    lcars_draw_button(cr, 20, 380, 160, 40, 10, theme, "warning", "SECURITY");
    lcars_draw_button(cr, 20, 440, 160, 40, 10, theme, "danger", "RED ALERT");
    
    // Draw text
    lcars_draw_text(cr, 20, 40, theme, "text", "STARFLEET OS", 18);
    lcars_draw_text(cr, width - 200, 40, theme, "text", "LCARS INTERFACE", 16);
    
    // Draw status bars
    lcars_draw_status_bar(cr, width - 280, 100, 240, 20, 0.75, theme, "accent");
    lcars_draw_status_bar(cr, width - 280, 140, 240, 20, 0.50, theme, "accent");
    lcars_draw_status_bar(cr, width - 280, 180, 240, 20, 0.90, theme, "accent");
    lcars_draw_status_bar(cr, width - 280, 220, 240, 20, 0.30, theme, "warning");
}

void lcars_draw_panel(cairo_t *cr, int x, int y, int width, int height, 
                     struct theme_data *theme, const char *color_key) {
    cairo_save(cr);
    
    cairo_set_source_rgba(cr, 
        theme_get_red(theme, color_key),
        theme_get_green(theme, color_key),
        theme_get_blue(theme, color_key),
        theme_get_alpha(theme, color_key));
    
    draw_rounded_rect(cr, x, y, width, height, 10);
    cairo_fill(cr);
    
    cairo_restore(cr);
}

void lcars_draw_button(cairo_t *cr, int x, int y, int width, int height, int radius,
                      struct theme_data *theme, const char *color_key, const char *label) {
    cairo_save(cr);
    
    // Draw button background
    cairo_set_source_rgba(cr, 
        theme_get_red(theme, color_key),
        theme_get_green(theme, color_key),
        theme_get_blue(theme, color_key),
        theme_get_alpha(theme, color_key));
    
    draw_rounded_rect(cr, x, y, width, height, radius);
    cairo_fill(cr);
    
    // Draw button text
    cairo_set_source_rgba(cr, 
        theme_get_red(theme, "text"),
        theme_get_green(theme, "text"),
        theme_get_blue(theme, "text"),
        theme_get_alpha(theme, "text"));
    
    PangoLayout *layout = pango_cairo_create_layout(cr);
    PangoFontDescription *font_desc = pango_font_description_from_string("LCARS 12");
    pango_layout_set_font_description(layout, font_desc);
    pango_layout_set_text(layout, label, -1);
    
    int text_width, text_height;
    pango_layout_get_size(layout, &text_width, &text_height);
    text_width /= PANGO_SCALE;
    text_height /= PANGO_SCALE;
    
    cairo_move_to(cr, x + (width - text_width) / 2, y + (height - text_height) / 2);
    pango_cairo_show_layout(cr, layout);
    
    pango_font_description_free(font_desc);
    g_object_unref(layout);
    
    cairo_restore(cr);
}

void lcars_draw_text(cairo_t *cr, int x, int y, struct theme_data *theme,
                    const char *color_key, const char *text, int size) {
    cairo_save(cr);
    
    cairo_set_source_rgba(cr, 
        theme_get_red(theme, color_key),
        theme_get_green(theme, color_key),
        theme_get_blue(theme, color_key),
        theme_get_alpha(theme, color_key));
    
    PangoLayout *layout = pango_cairo_create_layout(cr);
    char font_str[32];
    snprintf(font_str, sizeof(font_str), "LCARS %d", size);
    PangoFontDescription *font_desc = pango_font_description_from_string(font_str);
    pango_layout_set_font_description(layout, font_desc);
    pango_layout_set_text(layout, text, -1);
    
    cairo_move_to(cr, x, y);
    pango_cairo_show_layout(cr, layout);
    
    pango_font_description_free(font_desc);
    g_object_unref(layout);
    
    cairo_restore(cr);
}

void lcars_draw_status_bar(cairo_t *cr, int x, int y, int width, int height, 
                          float value, struct theme_data *theme, const char *color_key) {
    cairo_save(cr);
    
    // Draw background
    cairo_set_source_rgba(cr, 
        theme_get_red(theme, "background"),
        theme_get_green(theme, "background"),
        theme_get_blue(theme, "background"),
        theme_get_alpha(theme, "background"));
    
    draw_rounded_rect(cr, x, y, width, height, height / 2);
    cairo_fill(cr);
    
    // Draw value
    cairo_set_source_rgba(cr, 
        theme_get_red(theme, color_key),
        theme_get_green(theme, color_key),
        theme_get_blue(theme, color_key),
        theme_get_alpha(theme, color_key));
    
    int value_width = width * value;
    if (value_width > 0) {
        draw_rounded_rect(cr, x, y, value_width, height, height / 2);
        cairo_fill(cr);
    }
    
    cairo_restore(cr);
}