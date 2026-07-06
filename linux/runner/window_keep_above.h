#ifndef WINDOW_KEEP_ABOVE_H_
#define WINDOW_KEEP_ABOVE_H_

#include <glib.h>
#include <gtk/gtk.h>

/// Returns TRUE when the default GDK display is Wayland.
gboolean emby_window_is_wayland(void);

/// Apply keep-above on a GTK toplevel (xdg-toplevel on Wayland, _NET_WM_STATE on X11).
void emby_window_set_keep_above(GtkWindow* window, gboolean keep_above);

#endif  // WINDOW_KEEP_ABOVE_H_
