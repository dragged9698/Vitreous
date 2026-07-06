#include "window_keep_above.h"

#include "window_keep_above_kde.h"

#include <gdk/gdk.h>

#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif
#ifdef GDK_WINDOWING_X11
#include <X11/Xlib.h>
#include <gdk/gdkx.h>
#endif

namespace {

guint g_wayland_reapply_source_id = 0;

void cancel_wayland_reapply(void) {
  if (g_wayland_reapply_source_id != 0) {
    g_source_remove(g_wayland_reapply_source_id);
    g_wayland_reapply_source_id = 0;
  }
}

}  // namespace

gboolean emby_window_is_wayland(void) {
  GdkDisplay* display = gdk_display_get_default();
  return display != nullptr && GDK_IS_WAYLAND_DISPLAY(display);
}

static void emby_flush_window(GtkWindow* window) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (display) gdk_display_flush(display);
}

static void emby_apply_keep_above_now(GtkWindow* window, gboolean keep_above) {
  GtkWidget* widget = GTK_WIDGET(window);
  if (!gtk_widget_get_realized(widget)) {
    gtk_widget_realize(widget);
  }

  gtk_window_set_keep_above(window, keep_above);

  GdkWindow* gdk_window = gtk_widget_get_window(widget);
  if (gdk_window) {
    gdk_window_set_keep_above(gdk_window, keep_above);
  }

#ifdef GDK_WINDOWING_X11
  if (gdk_window && GDK_IS_X11_WINDOW(gdk_window)) {
    GdkDisplay* gdk_display = gdk_window_get_display(gdk_window);
    Display* xdisplay = gdk_x11_display_get_xdisplay(gdk_display);
    Window xid = gdk_x11_window_get_xid(gdk_window);
    if (xdisplay && xid) {
      Atom net_wm_state = XInternAtom(xdisplay, "_NET_WM_STATE", False);
      Atom above = XInternAtom(xdisplay, "_NET_WM_STATE_ABOVE", False);
      XEvent xev = {};
      xev.xclient.type = ClientMessage;
      xev.xclient.serial = 0;
      xev.xclient.send_event = True;
      xev.xclient.display = xdisplay;
      xev.xclient.window = xid;
      xev.xclient.message_type = net_wm_state;
      xev.xclient.format = 32;
      xev.xclient.data.l[0] = keep_above ? 1 : 0;
      xev.xclient.data.l[1] = above;
      xev.xclient.data.l[2] = 0;
      xev.xclient.data.l[3] = 1;
      xev.xclient.data.l[4] = 0;
      XSendEvent(xdisplay, DefaultRootWindow(xdisplay), False,
                 SubstructureNotifyMask | SubstructureRedirectMask, &xev);
      XFlush(xdisplay);
      g_message("EmbyWindowKeepAbove: X11 _NET_WM_STATE_ABOVE=%d xid=%lu", keep_above,
                static_cast<unsigned long>(xid));
    }
  }
#endif

  if (keep_above) {
    gtk_window_present(window);
  }
  emby_flush_window(window);

  g_message("EmbyWindowKeepAbove: keep_above=%d wayland=%d kde=%d title=%s", keep_above,
            emby_window_is_wayland(), emby_is_kde_session(), gtk_window_get_title(window));
}

static gboolean emby_reapply_keep_above_cb(gpointer user_data) {
  g_wayland_reapply_source_id = 0;
  GtkWindow* window = GTK_WINDOW(user_data);
  emby_apply_keep_above_now(window, TRUE);
  if (emby_window_is_wayland() && emby_is_kde_session()) {
    emby_kde_kwin_set_keep_above(TRUE);
  }
  g_object_unref(window);
  return G_SOURCE_REMOVE;
}

void emby_window_set_keep_above(GtkWindow* window, gboolean keep_above) {
  if (!window) return;

  if (!keep_above) {
    cancel_wayland_reapply();
  }

  emby_apply_keep_above_now(window, keep_above);

  // KDE Wayland: GTK keep-above does not update KWin stacking — use KWin scripting.
  if (emby_window_is_wayland() && emby_is_kde_session()) {
    emby_kde_kwin_set_keep_above(keep_above);
  }

  // Non-KDE Wayland: re-apply GTK once (some compositors drop the first commit).
  if (keep_above && emby_window_is_wayland() && !emby_is_kde_session()) {
    cancel_wayland_reapply();
    g_object_ref(window);
    g_wayland_reapply_source_id = g_timeout_add(100, emby_reapply_keep_above_cb, window);
  }
}
