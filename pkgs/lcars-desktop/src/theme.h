#ifndef THEME_H
#define THEME_H

/**
 * Theme data structure
 */
struct theme_data {
    char *mode;
    char *primary;
    char *secondary;
    char *accent;
    char *background;
    char *text;
    char *warning;
    char *danger;
};

/**
 * Create a new theme
 * 
 * @param mode Theme mode (starfleet, section31, borg, terran, holodeck)
 * @return Newly allocated theme data
 */
struct theme_data *theme_create(const char *mode);

/**
 * Destroy a theme
 * 
 * @param theme Theme data to destroy
 */
void theme_destroy(struct theme_data *theme);

/**
 * Get the red component of a color
 * 
 * @param theme Theme data
 * @param color_key Color key (primary, secondary, accent, background, text, warning, danger)
 * @return Red component (0.0-1.0)
 */
double theme_get_red(struct theme_data *theme, const char *color_key);

/**
 * Get the green component of a color
 * 
 * @param theme Theme data
 * @param color_key Color key (primary, secondary, accent, background, text, warning, danger)
 * @return Green component (0.0-1.0)
 */
double theme_get_green(struct theme_data *theme, const char *color_key);

/**
 * Get the blue component of a color
 * 
 * @param theme Theme data
 * @param color_key Color key (primary, secondary, accent, background, text, warning, danger)
 * @return Blue component (0.0-1.0)
 */
double theme_get_blue(struct theme_data *theme, const char *color_key);

/**
 * Get the alpha component of a color
 * 
 * @param theme Theme data
 * @param color_key Color key (primary, secondary, accent, background, text, warning, danger)
 * @return Alpha component (0.0-1.0)
 */
double theme_get_alpha(struct theme_data *theme, const char *color_key);

/**
 * Get the color as a hex string
 * 
 * @param theme Theme data
 * @param color_key Color key (primary, secondary, accent, background, text, warning, danger)
 * @return Color as hex string (e.g., "#CC99CC")
 */
const char *theme_get_color(struct theme_data *theme, const char *color_key);

/**
 * Set the current theme mode
 * 
 * @param theme Theme data
 * @param mode Theme mode (starfleet, section31, borg, terran, holodeck)
 * @return 0 on success, -1 on failure
 */
int theme_set_mode(struct theme_data *theme, const char *mode);

#endif /* THEME_H */