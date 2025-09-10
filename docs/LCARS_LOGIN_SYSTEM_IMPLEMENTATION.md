# LCARS Login System Implementation
# Starfleet OS Authentication Framework

## Overview

The LCARS login system provides a secure, visually consistent authentication experience that maintains the Star Trek LCARS design language. This document outlines the implementation plan for creating a complete LCARS-themed login system for Starfleet OS.

## Design Principles

1. **Visual Consistency**: Maintain LCARS design language throughout the authentication process
2. **Security**: Implement robust authentication mechanisms
3. **Role-Based Access**: Support different user roles with appropriate permissions
4. **Mode-Specific Theming**: Apply different visual styles based on operational mode
5. **Biometric Options**: Support advanced authentication methods where hardware allows

## Implementation Components

### 1. LCARS Display Manager

#### Requirements
- Create a custom display manager based on LCARS design
- Support different authentication methods
- Implement mode-specific theming
- Provide smooth transition from boot to login

#### Implementation
```nix
# In modules/lcars/login-manager.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-login;
  modeColors = import ../modes/mode-colors.nix;
  currentMode = config.services.lcars-display.mode or "starfleet";
  loginTheme = modeColors.${currentMode} or modeColors.starfleet;
in {
  options.services.lcars-login = {
    enable = mkEnableOption "LCARS login manager";
    
    defaultUser = mkOption {
      type = types.str;
      default = "";
      description = "Default user to pre-select (leave empty for no default)";
    };
    
    autoLogin = mkOption {
      type = types.bool;
      default = false;
      description = "Enable auto-login for default user";
    };
    
    biometricAuth = mkOption {
      type = types.bool;
      default = false;
      description = "Enable biometric authentication if hardware supports it";
    };
    
    voiceAuth = mkOption {
      type = types.bool;
      default = false;
      description = "Enable voice authentication if hardware supports it";
    };
    
    sessionTypes = mkOption {
      type = types.listOf types.str;
      default = [ "lcars" "lcars-lite" "fallback" ];
      description = "Available session types";
    };
  };
  
  config = mkIf cfg.enable {
    # Disable other display managers
    services.xserver.displayManager.gdm.enable = false;
    services.xserver.displayManager.sddm.enable = false;
    services.xserver.displayManager.lightdm.enable = false;
    
    # Enable custom LCARS display manager
    services.xserver.displayManager.lcars = {
      enable = true;
      theme = currentMode;
      defaultSession = "lcars";
      autoLogin = mkIf cfg.autoLogin {
        enable = true;
        user = cfg.defaultUser;
      };
    };
    
    # Add PAM configuration for biometric auth if enabled
    security.pam.services.lcars-login = mkIf cfg.biometricAuth {
      fprintAuth = true;
    };
    
    # Add voice authentication if enabled
    security.pam.services.lcars-login = mkIf cfg.voiceAuth {
      voiceAuth = true;
    };
    
    # Install required packages
    environment.systemPackages = with pkgs; [
      lcars-login-manager
      lcars-auth-tools
    ] ++ optionals cfg.biometricAuth [
      fprintd
      libfprint
    ] ++ optionals cfg.voiceAuth [
      lcars-voice-auth
    ];
    
    # Create systemd service for LCARS login manager
    systemd.services.lcars-login-manager = {
      description = "LCARS Login Manager";
      wantedBy = [ "graphical.target" ];
      after = [ "systemd-user-sessions.service" "plymouth-quit.service" ];
      conflicts = [ "getty@tty1.service" ];
      
      serviceConfig = {
        ExecStart = "${pkgs.lcars-login-manager}/bin/lcars-login-manager";
        Restart = "always";
        RestartSec = 10;
        StandardInput = "tty";
        StandardOutput = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = "yes";
        TTYVHangup = "yes";
        TTYVTDisallocate = "yes";
      };
      
      environment = {
        LCARS_MODE = currentMode;
        LCARS_THEME_PRIMARY = loginTheme.primary;
        LCARS_THEME_SECONDARY = loginTheme.secondary;
        LCARS_THEME_ACCENT = loginTheme.accent;
        LCARS_THEME_BACKGROUND = loginTheme.background;
        LCARS_BIOMETRIC = lib.boolToString cfg.biometricAuth;
        LCARS_VOICE_AUTH = lib.boolToString cfg.voiceAuth;
      };
    };
  };
}
```

### 2. Authentication Backend

#### Requirements
- Implement secure authentication mechanisms
- Support multiple authentication methods
- Integrate with PAM for system authentication
- Support role-based access control

#### Implementation
```c
// src/auth/lcars-auth.c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <security/pam_appl.h>
#include <security/pam_misc.h>

typedef enum {
    AUTH_PASSWORD,
    AUTH_BIOMETRIC,
    AUTH_VOICE,
    AUTH_MULTI_FACTOR
} AuthMethod;

typedef struct {
    char* username;
    char* display;
    AuthMethod method;
    int role_level;
    char* session_type;
} AuthRequest;

static int conv_func(int num_msg, const struct pam_message **msg,
                    struct pam_response **resp, void *appdata_ptr) {
    AuthRequest *req = (AuthRequest *)appdata_ptr;
    struct pam_response *reply = calloc(num_msg, sizeof(struct pam_response));
    
    if (reply == NULL) {
        return PAM_CONV_ERR;
    }
    
    for (int i = 0; i < num_msg; i++) {
        switch (msg[i]->msg_style) {
            case PAM_PROMPT_ECHO_ON:
                reply[i].resp = strdup(req->username);
                break;
            case PAM_PROMPT_ECHO_OFF:
                // In a real implementation, this would be handled by the UI
                // For now, we'll just use a placeholder
                reply[i].resp = strdup("password_placeholder");
                break;
            case PAM_ERROR_MSG:
                fprintf(stderr, "PAM Error: %s\n", msg[i]->msg);
                break;
            case PAM_TEXT_INFO:
                printf("PAM Info: %s\n", msg[i]->msg);
                break;
        }
    }
    
    *resp = reply;
    return PAM_SUCCESS;
}

int authenticate_user(AuthRequest *req) {
    pam_handle_t *pamh = NULL;
    struct pam_conv conv = {
        conv_func,
        req
    };
    
    int ret = pam_start("lcars-login", req->username, &conv, &pamh);
    if (ret != PAM_SUCCESS) {
        fprintf(stderr, "Failed to start PAM: %s\n", pam_strerror(pamh, ret));
        return 0;
    }
    
    // Set PAM environment variables for different auth methods
    switch (req->method) {
        case AUTH_BIOMETRIC:
            pam_set_item(pamh, PAM_AUTHTOK_TYPE, "biometric");
            break;
        case AUTH_VOICE:
            pam_set_item(pamh, PAM_AUTHTOK_TYPE, "voice");
            break;
        case AUTH_MULTI_FACTOR:
            pam_set_item(pamh, PAM_AUTHTOK_TYPE, "multifactor");
            break;
        default:
            pam_set_item(pamh, PAM_AUTHTOK_TYPE, "password");
            break;
    }
    
    // Authenticate user
    ret = pam_authenticate(pamh, 0);
    if (ret != PAM_SUCCESS) {
        fprintf(stderr, "Authentication failed: %s\n", pam_strerror(pamh, ret));
        pam_end(pamh, ret);
        return 0;
    }
    
    // Check account validity
    ret = pam_acct_mgmt(pamh, 0);
    if (ret != PAM_SUCCESS) {
        fprintf(stderr, "Account validation failed: %s\n", pam_strerror(pamh, ret));
        pam_end(pamh, ret);
        return 0;
    }
    
    // Set credentials
    ret = pam_setcred(pamh, PAM_ESTABLISH_CRED);
    if (ret != PAM_SUCCESS) {
        fprintf(stderr, "Failed to establish credentials: %s\n", pam_strerror(pamh, ret));
        pam_end(pamh, ret);
        return 0;
    }
    
    // Open session
    ret = pam_open_session(pamh, 0);
    if (ret != PAM_SUCCESS) {
        fprintf(stderr, "Failed to open session: %s\n", pam_strerror(pamh, ret));
        pam_setcred(pamh, PAM_DELETE_CRED);
        pam_end(pamh, ret);
        return 0;
    }
    
    // Set environment variables for the session
    pam_putenv(pamh, "LCARS_USER_ROLE_LEVEL=req->role_level");
    pam_putenv(pamh, "LCARS_SESSION_TYPE=req->session_type");
    
    // Success
    pam_end(pamh, PAM_SUCCESS);
    return 1;
}
```

### 3. LCARS Login UI

#### Requirements
- Create LCARS-themed login interface
- Support different authentication methods
- Implement mode-specific theming
- Provide smooth animations and transitions

#### Implementation
```c
// src/ui/lcars-login-ui.c
#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include <cairo.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../auth/lcars-auth.h"

typedef struct {
    GtkWidget *window;
    GtkWidget *username_entry;
    GtkWidget *password_entry;
    GtkWidget *login_button;
    GtkWidget *session_combo;
    GtkWidget *biometric_button;
    GtkWidget *voice_button;
    GtkWidget *error_label;
    
    char *theme_primary;
    char *theme_secondary;
    char *theme_accent;
    char *theme_background;
    
    gboolean biometric_available;
    gboolean voice_available;
} LcarsLoginUI;

static void draw_lcars_frame(GtkWidget *widget, cairo_t *cr, gpointer data) {
    LcarsLoginUI *ui = (LcarsLoginUI *)data;
    GdkRGBA primary, secondary, accent, background;
    
    // Parse colors
    gdk_rgba_parse(&primary, ui->theme_primary);
    gdk_rgba_parse(&secondary, ui->theme_secondary);
    gdk_rgba_parse(&accent, ui->theme_accent);
    gdk_rgba_parse(&background, ui->theme_background);
    
    // Get dimensions
    int width = gtk_widget_get_allocated_width(widget);
    int height = gtk_widget_get_allocated_height(widget);
    
    // Draw background
    cairo_set_source_rgba(cr, background.red, background.green, background.blue, background.alpha);
    cairo_rectangle(cr, 0, 0, width, height);
    cairo_fill(cr);
    
    // Draw LCARS frame elements
    
    // Left sidebar
    cairo_set_source_rgba(cr, primary.red, primary.green, primary.blue, primary.alpha);
    cairo_rectangle(cr, 0, 0, 100, height);
    cairo_fill(cr);
    
    // Top bar
    cairo_set_source_rgba(cr, secondary.red, secondary.green, secondary.blue, secondary.alpha);
    cairo_rectangle(cr, 100, 0, width - 100, 60);
    cairo_fill(cr);
    
    // Bottom bar
    cairo_set_source_rgba(cr, secondary.red, secondary.green, secondary.blue, secondary.alpha);
    cairo_rectangle(cr, 100, height - 60, width - 100, 60);
    cairo_fill(cr);
    
    // Right sidebar elements
    cairo_set_source_rgba(cr, accent.red, accent.green, accent.blue, accent.alpha);
    cairo_rectangle(cr, width - 80, 60, 80, 100);
    cairo_fill(cr);
    
    cairo_set_source_rgba(cr, accent.red, accent.green, accent.blue, accent.alpha);
    cairo_rectangle(cr, width - 80, height - 160, 80, 100);
    cairo_fill(cr);
    
    // Draw LCARS text elements
    cairo_select_font_face(cr, "LCARS", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 24);
    cairo_set_source_rgb(cr, 1, 1, 1);
    
    cairo_move_to(cr, 20, 40);
    cairo_show_text(cr, "LCARS");
    
    cairo_move_to(cr, 20, 80);
    cairo_show_text(cr, "LOGIN");
    
    cairo_move_to(cr, 20, 120);
    cairo_show_text(cr, "AUTH");
    
    cairo_move_to(cr, 150, 40);
    cairo_show_text(cr, "STARFLEET OS AUTHENTICATION");
    
    cairo_move_to(cr, 150, height - 30);
    cairo_show_text(cr, "ENTER CREDENTIALS");
}

static void on_login_clicked(GtkButton *button, gpointer data) {
    LcarsLoginUI *ui = (LcarsLoginUI *)data;
    const char *username = gtk_entry_get_text(GTK_ENTRY(ui->username_entry));
    const char *password = gtk_entry_get_text(GTK_ENTRY(ui->password_entry));
    const char *session_type = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(ui->session_combo));
    
    if (strlen(username) == 0) {
        gtk_label_set_text(GTK_LABEL(ui->error_label), "Please enter a username");
        return;
    }
    
    // Create auth request
    AuthRequest req;
    req.username = strdup(username);
    req.display = getenv("DISPLAY");
    req.method = AUTH_PASSWORD;
    req.role_level = 1; // Default role level
    req.session_type = strdup(session_type);
    
    // Authenticate user
    if (authenticate_user(&req)) {
        // Authentication successful
        // Start the selected session
        char cmd[256];
        sprintf(cmd, "exec dbus-launch --exit-with-session %s-session", session_type);
        system(cmd);
        
        // Exit the login manager
        gtk_main_quit();
    } else {
        // Authentication failed
        gtk_label_set_text(GTK_LABEL(ui->error_label), "Authentication failed");
    }
    
    // Clean up
    free(req.username);
    free(req.session_type);
}

static void on_biometric_clicked(GtkButton *button, gpointer data) {
    LcarsLoginUI *ui = (LcarsLoginUI *)data;
    const char *username = gtk_entry_get_text(GTK_ENTRY(ui->username_entry));
    const char *session_type = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(ui->session_combo));
    
    if (strlen(username) == 0) {
        gtk_label_set_text(GTK_LABEL(ui->error_label), "Please enter a username");
        return;
    }
    
    // Create auth request
    AuthRequest req;
    req.username = strdup(username);
    req.display = getenv("DISPLAY");
    req.method = AUTH_BIOMETRIC;
    req.role_level = 1; // Default role level
    req.session_type = strdup(session_type);
    
    // Authenticate user
    if (authenticate_user(&req)) {
        // Authentication successful
        // Start the selected session
        char cmd[256];
        sprintf(cmd, "exec dbus-launch --exit-with-session %s-session", session_type);
        system(cmd);
        
        // Exit the login manager
        gtk_main_quit();
    } else {
        // Authentication failed
        gtk_label_set_text(GTK_LABEL(ui->error_label), "Biometric authentication failed");
    }
    
    // Clean up
    free(req.username);
    free(req.session_type);
}

static void on_voice_clicked(GtkButton *button, gpointer data) {
    LcarsLoginUI *ui = (LcarsLoginUI *)data;
    const char *username = gtk_entry_get_text(GTK_ENTRY(ui->username_entry));
    const char *session_type = gtk_combo_box_text_get_active_text(GTK_COMBO_BOX_TEXT(ui->session_combo));
    
    if (strlen(username) == 0) {
        gtk_label_set_text(GTK_LABEL(ui->error_label), "Please enter a username");
        return;
    }
    
    // Create auth request
    AuthRequest req;
    req.username = strdup(username);
    req.display = getenv("DISPLAY");
    req.method = AUTH_VOICE;
    req.role_level = 1; // Default role level
    req.session_type = strdup(session_type);
    
    // Authenticate user
    if (authenticate_user(&req)) {
        // Authentication successful
        // Start the selected session
        char cmd[256];
        sprintf(cmd, "exec dbus-launch --exit-with-session %s-session", session_type);
        system(cmd);
        
        // Exit the login manager
        gtk_main_quit();
    } else {
        // Authentication failed
        gtk_label_set_text(GTK_LABEL(ui->error_label), "Voice authentication failed");
    }
    
    // Clean up
    free(req.username);
    free(req.session_type);
}

int main(int argc, char *argv[]) {
    // Initialize GTK
    gtk_init(&argc, &argv);
    
    // Create UI
    LcarsLoginUI ui;
    
    // Get theme colors from environment
    ui.theme_primary = getenv("LCARS_THEME_PRIMARY");
    ui.theme_secondary = getenv("LCARS_THEME_SECONDARY");
    ui.theme_accent = getenv("LCARS_THEME_ACCENT");
    ui.theme_background = getenv("LCARS_THEME_BACKGROUND");
    
    // Check for biometric and voice auth
    const char *biometric = getenv("LCARS_BIOMETRIC");
    const char *voice = getenv("LCARS_VOICE_AUTH");
    
    ui.biometric_available = (biometric != NULL && strcmp(biometric, "true") == 0);
    ui.voice_available = (voice != NULL && strcmp(voice, "true") == 0);
    
    // Create window
    ui.window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(ui.window), "LCARS Login");
    gtk_window_set_default_size(GTK_WINDOW(ui.window), 800, 600);
    gtk_window_set_position(GTK_WINDOW(ui.window), GTK_WIN_POS_CENTER);
    gtk_window_set_decorated(GTK_WINDOW(ui.window), FALSE);
    
    // Create drawing area for LCARS frame
    GtkWidget *drawing_area = gtk_drawing_area_new();
    g_signal_connect(G_OBJECT(drawing_area), "draw", G_CALLBACK(draw_lcars_frame), &ui);
    
    // Create login form
    GtkWidget *form_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
    gtk_widget_set_margin_start(form_box, 150);
    gtk_widget_set_margin_end(form_box, 150);
    gtk_widget_set_margin_top(form_box, 100);
    gtk_widget_set_margin_bottom(form_box, 100);
    
    // Username entry
    GtkWidget *username_label = gtk_label_new("Username:");
    gtk_widget_set_halign(username_label, GTK_ALIGN_START);
    ui.username_entry = gtk_entry_new();
    
    // Password entry
    GtkWidget *password_label = gtk_label_new("Password:");
    gtk_widget_set_halign(password_label, GTK_ALIGN_START);
    ui.password_entry = gtk_entry_new();
    gtk_entry_set_visibility(GTK_ENTRY(ui.password_entry), FALSE);
    
    // Session type combo
    GtkWidget *session_label = gtk_label_new("Session:");
    gtk_widget_set_halign(session_label, GTK_ALIGN_START);
    ui.session_combo = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(ui.session_combo), "lcars");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(ui.session_combo), "lcars-lite");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(ui.session_combo), "fallback");
    gtk_combo_box_set_active(GTK_COMBO_BOX(ui.session_combo), 0);
    
    // Login button
    ui.login_button = gtk_button_new_with_label("Login");
    g_signal_connect(G_OBJECT(ui.login_button), "clicked", G_CALLBACK(on_login_clicked), &ui);
    
    // Biometric button
    if (ui.biometric_available) {
        ui.biometric_button = gtk_button_new_with_label("Biometric Login");
        g_signal_connect(G_OBJECT(ui.biometric_button), "clicked", G_CALLBACK(on_biometric_clicked), &ui);
    }
    
    // Voice button
    if (ui.voice_available) {
        ui.voice_button = gtk_button_new_with_label("Voice Login");
        g_signal_connect(G_OBJECT(ui.voice_button), "clicked", G_CALLBACK(on_voice_clicked), &ui);
    }
    
    // Error label
    ui.error_label = gtk_label_new("");
    gtk_widget_set_halign(ui.error_label, GTK_ALIGN_CENTER);
    
    // Add widgets to form
    gtk_box_pack_start(GTK_BOX(form_box), username_label, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form_box), ui.username_entry, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form_box), password_label, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form_box), ui.password_entry, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form_box), session_label, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form_box), ui.session_combo, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(form_box), ui.login_button, FALSE, FALSE, 10);
    
    if (ui.biometric_available) {
        gtk_box_pack_start(GTK_BOX(form_box), ui.biometric_button, FALSE, FALSE, 0);
    }
    
    if (ui.voice_available) {
        gtk_box_pack_start(GTK_BOX(form_box), ui.voice_button, FALSE, FALSE, 0);
    }
    
    gtk_box_pack_start(GTK_BOX(form_box), ui.error_label, FALSE, FALSE, 10);
    
    // Create overlay
    GtkWidget *overlay = gtk_overlay_new();
    gtk_container_add(GTK_CONTAINER(overlay), drawing_area);
    gtk_overlay_add_overlay(GTK_OVERLAY(overlay), form_box);
    
    // Add overlay to window
    gtk_container_add(GTK_CONTAINER(ui.window), overlay);
    
    // Connect signals
    g_signal_connect(G_OBJECT(ui.window), "destroy", G_CALLBACK(gtk_main_quit), NULL);
    
    // Show all widgets
    gtk_widget_show_all(ui.window);
    
    // Start main loop
    gtk_main();
    
    return 0;
}
```

### 4. Role-Based Access Control

#### Requirements
- Implement role-based access control for different user types
- Define permission levels for different operations
- Integrate with system permissions

#### Implementation
```nix
# In modules/lcars/role-based-access.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-rbac;
  
  roleType = types.submodule {
    options = {
      description = mkOption {
        type = types.str;
        default = "";
        description = "Role description";
      };
      
      level = mkOption {
        type = types.int;
        default = 1;
        description = "Role level (1-10)";
      };
      
      allowedCommands = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Commands allowed for this role";
      };
      
      allowedServices = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Services allowed for this role";
      };
      
      sudoAccess = mkOption {
        type = types.bool;
        default = false;
        description = "Allow sudo access";
      };
    };
  };
in {
  options.services.lcars-rbac = {
    enable = mkEnableOption "LCARS role-based access control";
    
    roles = mkOption {
      type = types.attrsOf roleType;
      default = {
        captain = {
          description = "Captain - Full system access";
          level = 10;
          allowedCommands = [ "*" ];
          allowedServices = [ "*" ];
          sudoAccess = true;
        };
        
        officer = {
          description = "Officer - Limited system access";
          level = 5;
          allowedCommands = [ "starfleet-*" "lcars-*" "fleet-*" ];
          allowedServices = [ "lcars-*" "fleet-*" ];
          sudoAccess = false;
        };
        
        ensign = {
          description = "Ensign - Basic system access";
          level = 1;
          allowedCommands = [ "starfleet-status" "lcars-display" ];
          allowedServices = [];
          sudoAccess = false;
        };
      };
      description = "Role definitions";
    };
    
    userRoles = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {};
      description = "User role assignments";
      example = {
        alice = [ "captain" ];
        bob = [ "officer" ];
        charlie = [ "ensign" ];
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Create polkit rules for role-based access
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        var roles = ${builtins.toJSON cfg.userRoles};
        var roleDefinitions = ${builtins.toJSON cfg.roles};
        
        // Get user roles
        var userRoles = roles[subject.user] || [];
        
        // Check if user has any roles
        if (userRoles.length === 0) {
          return polkit.Result.NOT_AUTHORIZED;
        }
        
        // Get highest role level
        var highestLevel = 0;
        for (var i = 0; i < userRoles.length; i++) {
          var role = userRoles[i];
          var roleLevel = roleDefinitions[role] ? roleDefinitions[role].level : 0;
          highestLevel = Math.max(highestLevel, roleLevel);
        }
        
        // Captain (level 10) can do anything
        if (highestLevel >= 10) {
          return polkit.Result.YES;
        }
        
        // Officer (level 5-9) can do most things
        if (highestLevel >= 5) {
          if (action.id.indexOf("org.freedesktop.lcars") === 0) {
            return polkit.Result.YES;
          }
          
          if (action.id.indexOf("org.freedesktop.fleet") === 0) {
            return polkit.Result.YES;
          }
        }
        
        // Ensign (level 1-4) can do basic things
        if (highestLevel >= 1) {
          if (action.id === "org.freedesktop.lcars.display") {
            return polkit.Result.YES;
          }
          
          if (action.id === "org.freedesktop.lcars.status") {
            return polkit.Result.YES;
          }
        }
        
        // Default: not authorized
        return polkit.Result.NOT_AUTHORIZED;
      });
    '';
    
    # Configure sudo access based on roles
    security.sudo.extraRules = flatten (mapAttrsToList (user: roles:
      map (role: 
        let
          roleConfig = cfg.roles.${role} or {};
          hasSudo = roleConfig.sudoAccess or false;
        in
          mkIf hasSudo {
            users = [ user ];
            commands = [
              {
                command = "ALL";
                options = [ "NOPASSWD" ];
              }
            ];
          }
      ) roles
    ) cfg.userRoles);
    
    # Create PAM module for role-based access
    security.pam.services.lcars-login.extraConfig = ''
      session required pam_exec.so ${pkgs.lcars-rbac}/bin/lcars-rbac-session
    '';
    
    # Install required packages
    environment.systemPackages = with pkgs; [
      lcars-rbac
    ];
  };
}
```

### 5. Biometric Authentication

#### Requirements
- Implement fingerprint authentication
- Support facial recognition where hardware allows
- Integrate with PAM for system authentication

#### Implementation
```nix
# In modules/lcars/biometric-auth.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-biometric;
in {
  options.services.lcars-biometric = {
    enable = mkEnableOption "LCARS biometric authentication";
    
    fingerprint = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable fingerprint authentication";
      };
      
      devices = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Fingerprint devices to use";
      };
    };
    
    facial = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable facial recognition";
      };
      
      camera = mkOption {
        type = types.str;
        default = "";
        description = "Camera device to use for facial recognition";
      };
      
      modelPath = mkOption {
        type = types.str;
        default = "${pkgs.lcars-facial-models}/share/lcars-facial/model";
        description = "Path to facial recognition model";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Enable fprintd for fingerprint authentication
    services.fprintd.enable = cfg.fingerprint.enable;
    
    # Configure PAM for fingerprint authentication
    security.pam.services.lcars-login = mkIf cfg.fingerprint.enable {
      fprintAuth = true;
    };
    
    # Configure facial recognition
    services.lcars-facial = mkIf cfg.facial.enable {
      enable = true;
      camera = cfg.facial.camera;
      modelPath = cfg.facial.modelPath;
    };
    
    # Create systemd service for facial recognition
    systemd.services.lcars-facial = mkIf cfg.facial.enable {
      description = "LCARS Facial Recognition Service";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        ExecStart = "${pkgs.lcars-facial}/bin/lcars-facial-service";
        Restart = "on-failure";
        RestartSec = 5;
      };
      
      environment = {
        LCARS_FACIAL_CAMERA = cfg.facial.camera;
        LCARS_FACIAL_MODEL = cfg.facial.modelPath;
      };
    };
    
    # Install required packages
    environment.systemPackages = with pkgs; [
      fprintd
      libfprint
    ] ++ optionals cfg.facial.enable [
      lcars-facial
      lcars-facial-models
    ];
  };
}
```

### 6. Voice Authentication

#### Requirements
- Implement voice recognition authentication
- Support voice commands for login
- Integrate with PAM for system authentication

#### Implementation
```nix
# In modules/lcars/voice-auth.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lcars-voice-auth;
in {
  options.services.lcars-voice-auth = {
    enable = mkEnableOption "LCARS voice authentication";
    
    microphoneDevice = mkOption {
      type = types.str;
      default = "default";
      description = "Microphone device to use for voice authentication";
    };
    
    modelPath = mkOption {
      type = types.str;
      default = "${pkgs.lcars-voice-models}/share/lcars-voice/model";
      description = "Path to voice recognition model";
    };
    
    commands = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable voice commands";
      };
      
      commandsPath = mkOption {
        type = types.str;
        default = "${pkgs.lcars-voice-commands}/share/lcars-voice/commands";
        description = "Path to voice commands definitions";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Create PAM module for voice authentication
    security.pam.services.lcars-login.extraConfig = ''
      auth sufficient ${pkgs.lcars-voice-auth}/lib/security/pam_lcars_voice.so
    '';
    
    # Create systemd service for voice recognition
    systemd.services.lcars-voice-service = {
      description = "LCARS Voice Recognition Service";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        ExecStart = "${pkgs.lcars-voice-auth}/bin/lcars-voice-service";
        Restart = "on-failure";
        RestartSec = 5;
      };
      
      environment = {
        LCARS_VOICE_DEVICE = cfg.microphoneDevice;
        LCARS_VOICE_MODEL = cfg.modelPath;
        LCARS_VOICE_COMMANDS = cfg.commands.enable ? cfg.commands.commandsPath : "";
      };
    };
    
    # Install required packages
    environment.systemPackages = with pkgs; [
      lcars-voice-auth
      lcars-voice-models
    ] ++ optionals cfg.commands.enable [
      lcars-voice-commands
    ];
  };
}
```

## Testing Plan

### 1. Virtual Machine Testing
- Test login system in QEMU/VirtualBox
- Verify all authentication methods work correctly
- Test with different screen resolutions
- Test with different hardware configurations

### 2. Hardware Testing
- Test on OptiPlex bridge hardware
- Test on laptop/portable hardware
- Test with different authentication devices
- Verify compatibility with different GPUs

### 3. Security Testing
- Test authentication bypass attempts
- Verify role-based access control
- Test with invalid credentials
- Test with multiple users

## Integration with Existing Components

### 1. Mode Switcher Integration
```nix
# In modules/modes/mode-switcher.nix
{ config, lib, pkgs, ... }:

# Add to existing mode-switcher.nix
{
  config = mkIf cfg.enable {
    # Existing configuration...
    
    # Add login system configuration
    services.lcars-login = {
      enable = true;
      defaultUser = "";
      autoLogin = false;
      biometricAuth = config.services.lcars-biometric.enable;
      voiceAuth = config.services.lcars-voice-auth.enable;
    };
    
    # Update login theme when mode changes
    system.activationScripts.updateLcarsLoginTheme = ''
      # Update login theme based on current mode
      if [ -f /etc/lcars/login-theme.conf ]; then
        sed -i 's/LCARS_MODE=.*/LCARS_MODE=${cfg.currentMode}/' /etc/lcars/login-theme.conf
      fi
    '';
  };
}
```

### 2. Display Server Integration
```nix
# In modules/lcars/display-server.nix
{ config, lib, pkgs, ... }:

# Add to existing display-server.nix
{
  config = mkIf cfg.enable {
    # Existing configuration...
    
    # Add login system integration
    services.lcars-display.loginTransition = mkIf config.services.lcars-login.enable {
      enable = true;
      duration = 1000; # milliseconds
    };
    
    # Add systemd target for login completion
    systemd.targets.lcars-login-complete = {
      description = "LCARS Login Complete";
      requires = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      wantedBy = [ "graphical.target" ];
    };
    
    # Add transition from login to display server
    systemd.services.lcars-display.wants = [ "lcars-login-complete.target" ];
  };
}
```

## Deliverables

1. **LCARS Login Manager**: Custom display manager with LCARS design
2. **Authentication Backend**: Secure authentication system with PAM integration
3. **LCARS Login UI**: Visually consistent login interface
4. **Role-Based Access Control**: Permission system for different user roles
5. **Biometric Authentication**: Fingerprint and facial recognition support
6. **Voice Authentication**: Voice recognition and command support
7. **NixOS Modules**: NixOS modules for LCARS login system configuration
8. **Documentation**: Complete documentation for the LCARS login system

## Timeline

1. **Week 1**: Design and implement LCARS login manager
2. **Week 2**: Create authentication backend and login UI
3. **Week 3**: Implement role-based access control
4. **Week 4**: Add biometric and voice authentication
5. **Week 5**: Testing and optimization

## Conclusion

The LCARS login system implementation will provide a secure, visually consistent authentication experience that maintains the Star Trek LCARS design language. By supporting multiple authentication methods and role-based access control, the system will provide both security and flexibility for different user types and operational modes.