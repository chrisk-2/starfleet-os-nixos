#ifndef DISPLAY_H
#define DISPLAY_H

/**
 * Display configuration structure
 */
struct display_config {
    char *resolution;
    int width;
    int height;
    int refresh_rate;
};

/**
 * Create a new display configuration
 * 
 * @param resolution Resolution string (e.g., "1920x1080")
 * @param refresh_rate Refresh rate in Hz
 * @return Newly allocated display configuration
 */
struct display_config *display_config_create(const char *resolution, int refresh_rate);

/**
 * Destroy a display configuration
 * 
 * @param config Display configuration to destroy
 */
void display_config_destroy(struct display_config *config);

/**
 * Parse a resolution string into width and height
 * 
 * @param resolution Resolution string (e.g., "1920x1080")
 * @param width Pointer to store width
 * @param height Pointer to store height
 * @return 0 on success, -1 on failure
 */
int display_parse_resolution(const char *resolution, int *width, int *height);

/**
 * Get available display modes
 * 
 * @return Array of available display modes
 */
char **display_get_modes(void);

/**
 * Set the current display mode
 * 
 * @param mode Display mode to set
 * @return 0 on success, -1 on failure
 */
int display_set_mode(const char *mode);

#endif /* DISPLAY_H */