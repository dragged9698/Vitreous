#ifndef WINDOW_PIP_H_
#define WINDOW_PIP_H_

#include <glib.h>
#include <gtk/gtk.h>

typedef struct {
  int x;
  int y;
  int width;
  int height;
} EmbyWindowBounds;

/// Enter frameless desktop PiP: undecorate, resize/move, Wayland CSD hint for KDE.
gboolean emby_window_enter_pip(GtkWindow* window, const EmbyWindowBounds* bounds);

/// Exit desktop PiP and restore decorations; [restore] may be NULL to use saved bounds.
gboolean emby_window_exit_pip(GtkWindow* window, const EmbyWindowBounds* restore);

gboolean emby_window_pip_is_active(void);

gboolean emby_window_get_bounds(GtkWindow* window, EmbyWindowBounds* out);

void emby_window_start_drag(GtkWindow* window);

#endif  // WINDOW_PIP_H_
