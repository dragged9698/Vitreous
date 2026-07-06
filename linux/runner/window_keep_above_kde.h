#ifndef WINDOW_KEEP_ABOVE_KDE_H_
#define WINDOW_KEEP_ABOVE_KDE_H_

#include <glib.h>
#include <gtk/gtk.h>

/// Returns TRUE on KDE Plasma sessions (KWin).
gboolean emby_is_kde_session(void);

/// KWin Wayland ignores GTK keep-above; set stacking via KWin scripting (by PID).
void emby_kde_kwin_set_keep_above(gboolean keep_above);

/// Plasma 6: temporary kwinrulesrc Overlay layer (above borderless fullscreen). [window] may be NULL.
void emby_kde_kwin_set_pip_overlay_layer(GtkWindow* window, gboolean enable);

#endif  // WINDOW_KEEP_ABOVE_KDE_H_
