#include "window_pip.h"

#include <gdk/gdk.h>

#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif

#include "window_keep_above.h"
#include "window_keep_above_kde.h"

namespace {

struct PipSavedState {
  gboolean active = FALSE;
  gboolean decorated = TRUE;
  gboolean resizable = TRUE;
  gboolean was_maximized = FALSE;
  gboolean was_fullscreen = FALSE;
  EmbyWindowBounds bounds = {};
  GtkWidget* titlebar = nullptr;
  gboolean titlebar_was_visible = FALSE;
  GtkCssProvider* css_provider = nullptr;
};

PipSavedState g_pip;

void ensure_realized(GtkWindow* window) {
  GtkWidget* widget = GTK_WIDGET(window);
  if (!gtk_widget_get_realized(widget)) {
    gtk_widget_realize(widget);
  }
}

GdkWindow* gdk_window_for(GtkWindow* window) {
  ensure_realized(window);
  return gtk_widget_get_window(GTK_WIDGET(window));
}

void announce_wayland_csd(GtkWindow* window) {
#ifdef GDK_WINDOWING_WAYLAND
  GdkWindow* gdk_window = gdk_window_for(window);
  if (gdk_window && GDK_IS_WAYLAND_WINDOW(gdk_window)) {
    gdk_wayland_window_announce_csd(gdk_window);
  }
#endif
}

void announce_wayland_ssd(GtkWindow* window) {
#ifdef GDK_WINDOWING_WAYLAND
  GdkWindow* gdk_window = gdk_window_for(window);
  if (gdk_window && GDK_IS_WAYLAND_WINDOW(gdk_window)) {
    gdk_wayland_window_announce_ssd(gdk_window);
  }
#endif
}

void hide_titlebar(GtkWindow* window) {
  GtkWidget* titlebar = gtk_window_get_titlebar(window);
  if (titlebar == nullptr) return;
  g_pip.titlebar = titlebar;
  g_pip.titlebar_was_visible = gtk_widget_get_visible(titlebar);
  gtk_widget_hide(titlebar);
}

void restore_titlebar(GtkWindow* window) {
  if (g_pip.titlebar == nullptr) return;
  if (g_pip.titlebar_was_visible) {
    gtk_widget_show(g_pip.titlebar);
  }
  g_pip.titlebar = nullptr;
  g_pip.titlebar_was_visible = FALSE;
}

void set_transparent_background(GtkWindow* window, gboolean transparent) {
  GtkWidget* widget = GTK_WIDGET(window);
  GtkStyleContext* context = gtk_widget_get_style_context(widget);

  if (transparent) {
    if (g_pip.css_provider == nullptr) {
      g_pip.css_provider = gtk_css_provider_new();
      const char* css = "window { background-color: rgba(0,0,0,0); }";
      gtk_css_provider_load_from_data(g_pip.css_provider, css, -1, nullptr);
      gtk_style_context_add_provider(
          context, GTK_STYLE_PROVIDER(g_pip.css_provider), GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
  } else if (g_pip.css_provider != nullptr) {
    gtk_style_context_remove_provider(context, GTK_STYLE_PROVIDER(g_pip.css_provider));
    g_object_unref(g_pip.css_provider);
    g_pip.css_provider = nullptr;
  }
}

void apply_bounds(GtkWindow* window, const EmbyWindowBounds* bounds) {
  if (bounds == nullptr) return;
  g_message("EmbyWindowPip: apply_bounds x=%d y=%d w=%d h=%d", bounds->x, bounds->y, bounds->width,
            bounds->height);
  gtk_window_resize(window, bounds->width, bounds->height);
  gtk_window_move(window, bounds->x, bounds->y);
}

struct DeferredPipBounds {
  GtkWindow* window;
  EmbyWindowBounds bounds;
  gboolean maximize = FALSE;
  gboolean fullscreen = FALSE;
};

gboolean deferred_apply_restore_bounds(gpointer user_data) {
  auto* data = static_cast<DeferredPipBounds*>(user_data);
  if (data->fullscreen) {
    gtk_window_fullscreen(data->window);
  } else if (data->maximize) {
    gtk_window_maximize(data->window);
  } else {
    apply_bounds(data->window, &data->bounds);
  }
  announce_wayland_ssd(data->window);
  gtk_window_present(data->window);
  delete data;
  return G_SOURCE_REMOVE;
}

void schedule_wayland_restore(GtkWindow* window, const EmbyWindowBounds* bounds, gboolean maximize,
                              gboolean fullscreen) {
#ifdef GDK_WINDOWING_WAYLAND
  GdkWindow* gdk_window = gdk_window_for(window);
  if (!gdk_window || !GDK_IS_WAYLAND_WINDOW(gdk_window)) return;
  auto* deferred = new DeferredPipBounds{window, bounds != nullptr ? *bounds : EmbyWindowBounds{}, maximize,
                                         fullscreen};
  g_idle_add(deferred_apply_restore_bounds, deferred);
#else
  (void)window;
  (void)bounds;
  (void)maximize;
  (void)fullscreen;
#endif
}

struct DeferredPipEnterBounds {
  GtkWindow* window;
  EmbyWindowBounds bounds;
};

gboolean deferred_apply_pip_bounds(gpointer user_data) {
  auto* data = static_cast<DeferredPipEnterBounds*>(user_data);
  apply_bounds(data->window, &data->bounds);
  announce_wayland_csd(data->window);
  gtk_window_present(data->window);
  delete data;
  return G_SOURCE_REMOVE;
}

void schedule_wayland_pip_bounds(GtkWindow* window, const EmbyWindowBounds* bounds) {
#ifdef GDK_WINDOWING_WAYLAND
  GdkWindow* gdk_window = gdk_window_for(window);
  if (!gdk_window || !GDK_IS_WAYLAND_WINDOW(gdk_window)) return;
  auto* deferred = new DeferredPipEnterBounds{window, *bounds};
  g_idle_add(deferred_apply_pip_bounds, deferred);
#else
  (void)window;
  (void)bounds;
#endif
}

void clear_window_state(GtkWindow* window) {
  if (gtk_window_is_maximized(window)) {
    gtk_window_unmaximize(window);
  }
  GdkWindow* gdk_window = gdk_window_for(window);
  if (gdk_window) {
    GdkWindowState state = gdk_window_get_state(gdk_window);
    if (state & GDK_WINDOW_STATE_FULLSCREEN) {
      gtk_window_unfullscreen(window);
    }
  }
}

struct DeferredPipOverlay {
  GtkWindow* window;
  gboolean enable;
};

gboolean deferred_pip_overlay_cb(gpointer user_data) {
  auto* data = static_cast<DeferredPipOverlay*>(user_data);
  emby_kde_kwin_set_pip_overlay_layer(data->window, data->enable);
  delete data;
  return G_SOURCE_REMOVE;
}

void set_pip_stacking(GtkWindow* window, gboolean enable) {
  emby_window_set_keep_above(window, enable);
  if (!emby_is_kde_session() || !emby_window_is_wayland()) return;
  if (enable) {
    auto* deferred = new DeferredPipOverlay{window, enable};
    g_timeout_add(300, deferred_pip_overlay_cb, deferred);
    return;
  }
  emby_kde_kwin_set_pip_overlay_layer(window, FALSE);
}

}  // namespace

gboolean emby_window_get_bounds(GtkWindow* window, EmbyWindowBounds* out) {
  if (!window || !out) return FALSE;
  gint x = 0;
  gint y = 0;
  gint width = 0;
  gint height = 0;
  gtk_window_get_position(window, &x, &y);
  gtk_window_get_size(window, &width, &height);
  out->x = x;
  out->y = y;
  out->width = width;
  out->height = height;
  return TRUE;
}

gboolean emby_window_pip_is_active(void) { return g_pip.active; }

gboolean emby_window_enter_pip(GtkWindow* window, const EmbyWindowBounds* bounds) {
  if (!window || !bounds || bounds->width < 1 || bounds->height < 1) return FALSE;
  if (g_pip.active) {
    apply_bounds(window, bounds);
    set_pip_stacking(window, TRUE);
    return TRUE;
  }

  ensure_realized(window);

  g_pip.was_maximized = gtk_window_is_maximized(window);
  GdkWindow* pre_gdk = gdk_window_for(window);
  g_pip.was_fullscreen =
      pre_gdk != nullptr && (gdk_window_get_state(pre_gdk) & GDK_WINDOW_STATE_FULLSCREEN) != 0;

  emby_window_get_bounds(window, &g_pip.bounds);
  g_message("EmbyWindowPip: enter saved bounds x=%d y=%d w=%d h=%d maximized=%d fullscreen=%d",
            g_pip.bounds.x, g_pip.bounds.y, g_pip.bounds.width, g_pip.bounds.height,
            g_pip.was_maximized, g_pip.was_fullscreen);

  clear_window_state(window);

  // After unmaximize, capture the restored normal geometry for fallback exit.
  if (g_pip.was_maximized || g_pip.was_fullscreen) {
    emby_window_get_bounds(window, &g_pip.bounds);
    g_message("EmbyWindowPip: enter post-unmaximize bounds x=%d y=%d w=%d h=%d", g_pip.bounds.x,
              g_pip.bounds.y, g_pip.bounds.width, g_pip.bounds.height);
  }

  g_pip.decorated = gtk_window_get_decorated(window);
  g_pip.resizable = gtk_window_get_resizable(window);

  hide_titlebar(window);
  gtk_window_set_decorated(window, FALSE);
  announce_wayland_csd(window);

  gtk_window_set_resizable(window, TRUE);
  gtk_window_set_deletable(window, TRUE);
  gtk_window_set_skip_taskbar_hint(window, FALSE);

  GdkWindow* gdk_window = gdk_window_for(window);
  if (gdk_window) {
    GdkGeometry geometry = {};
    geometry.min_width = 240;
    geometry.min_height = 135;
    gdk_window_set_geometry_hints(
        gdk_window, &geometry, static_cast<GdkWindowHints>(GDK_HINT_MIN_SIZE));
  }

  set_transparent_background(window, TRUE);
  apply_bounds(window, bounds);
  schedule_wayland_pip_bounds(window, bounds);
  set_pip_stacking(window, TRUE);

  g_pip.active = TRUE;
  return TRUE;
}

gboolean emby_window_exit_pip(GtkWindow* window, const EmbyWindowBounds* restore) {
  if (!window || !g_pip.active) return FALSE;

  const gboolean use_maximize = g_pip.was_maximized;
  const gboolean use_fullscreen = g_pip.was_fullscreen;
  const EmbyWindowBounds* target = restore != nullptr ? restore : &g_pip.bounds;

  g_message("EmbyWindowPip: exit restore x=%d y=%d w=%d h=%d maximized=%d fullscreen=%d fromDart=%d",
            target->x, target->y, target->width, target->height, use_maximize, use_fullscreen,
            restore != nullptr);

  set_transparent_background(window, FALSE);
  set_pip_stacking(window, FALSE);

  gtk_window_set_decorated(window, g_pip.decorated);
  gtk_window_set_resizable(window, g_pip.resizable);

  restore_titlebar(window);
  announce_wayland_ssd(window);

  if (gdk_window_for(window)) {
    GdkGeometry geometry = {};
    geometry.min_width = 320;
    geometry.min_height = 240;
    gdk_window_set_geometry_hints(
        gdk_window_for(window), &geometry, static_cast<GdkWindowHints>(GDK_HINT_MIN_SIZE));
  }

  if (use_fullscreen) {
    gtk_window_fullscreen(window);
    schedule_wayland_restore(window, nullptr, FALSE, TRUE);
  } else if (use_maximize) {
    apply_bounds(window, target);
    gtk_window_maximize(window);
    schedule_wayland_restore(window, target, TRUE, FALSE);
  } else {
    apply_bounds(window, target);
    schedule_wayland_restore(window, target, FALSE, FALSE);
  }

  g_pip.active = FALSE;
  g_pip.was_maximized = FALSE;
  g_pip.was_fullscreen = FALSE;
  return TRUE;
}

void emby_window_start_drag(GtkWindow* window) {
  if (!window) return;
  ensure_realized(window);

  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* device = gdk_seat_get_pointer(seat);
  if (!device) return;

  gint root_x = 0;
  gint root_y = 0;
  gdk_device_get_position(device, nullptr, &root_x, &root_y);
  const guint32 timestamp = static_cast<guint32>(g_get_monotonic_time());

  gtk_window_begin_move_drag(window, 1, root_x, root_y, timestamp);
}
