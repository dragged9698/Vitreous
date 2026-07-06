#include "window_keep_above_kde.h"

#include <gdk/gdk.h>
#include <gio/gio.h>
#include <strings.h>
#include <unistd.h>

#ifndef APPLICATION_ID
#define APPLICATION_ID "com.dragged9698.vitreous"
#endif

namespace {

static const char kPipOverlayRuleId[] = "vitreous-pip-overlay-layer";
static const char kKWinRulesFile[] = "kwinrulesrc";

// KWin::Rules::Force and KWin::OverlayLayer.
static const int kLayerRuleForce = 2;
static const int kLayerOverlay = 9;
static const int kStringMatchSubstring = 2;
static const int kExpectedOverlayLayer = 9;

gboolean env_contains_kde(const char* name) {
  const char* value = g_getenv(name);
  if (value == nullptr || value[0] == '\0') return FALSE;
  return strcasestr(value, "kde") != nullptr || strcasestr(value, "plasma") != nullptr;
}

gboolean spawn_sync_argv(const char* const* argv, gchar** stdout_buf) {
  GError* error = nullptr;
  gint exit_status = 0;
  if (!g_spawn_sync(nullptr, const_cast<gchar**>(argv), nullptr, G_SPAWN_SEARCH_PATH, nullptr,
                    nullptr, stdout_buf, nullptr, &exit_status, &error)) {
    g_message("EmbyKWinOverlay: spawn %s failed: %s", argv[0], error ? error->message : "unknown");
    if (error) g_error_free(error);
    return FALSE;
  }
  if (!g_spawn_check_wait_status(exit_status, &error)) {
    g_message("EmbyKWinOverlay: %s exit %d: %s", argv[0], exit_status,
              error ? error->message : "unknown");
    if (error) g_error_free(error);
    return FALSE;
  }
  return TRUE;
}

gboolean kwriteconfig(const char* group, const char* key, const char* value) {
  const char* argv[] = {"kwriteconfig6", "--file", kKWinRulesFile, "--group",  group,
                        "--key",         key,        value,          nullptr};
  return spawn_sync_argv(argv, nullptr);
}

gboolean kwriteconfig_int(const char* group, const char* key, int value) {
  g_autofree gchar* text = g_strdup_printf("%d", value);
  return kwriteconfig(group, key, text);
}

gboolean kwriteconfig_bool(const char* group, const char* key, gboolean value) {
  const char* argv[] = {"kwriteconfig6", "--file", kKWinRulesFile, "--group", group, "--key", key,
                        "--type",        "bool",   value ? "true" : "false", nullptr};
  return spawn_sync_argv(argv, nullptr);
}

gboolean kdelete_group(const char* group) {
  const char* argv[] = {"kwriteconfig6", "--file", kKWinRulesFile, "--group", group, "--delete", nullptr};
  return spawn_sync_argv(argv, nullptr);
}

gboolean kreadconfig(const char* group, const char* key, gchar** out) {
  const char* argv[] = {"kreadconfig6", "--file", kKWinRulesFile, "--group", group, "--key", key, nullptr};
  gchar* stdout_buf = nullptr;
  const gboolean ok = spawn_sync_argv(argv, &stdout_buf);
  if (!ok) return FALSE;
  if (stdout_buf != nullptr) g_strstrip(stdout_buf);
  *out = stdout_buf;
  return TRUE;
}

gboolean rule_id_listed(const char* rules_csv, const char* rule_id) {
  if (rules_csv == nullptr || rules_csv[0] == '\0') return FALSE;
  g_auto(GStrv) parts = g_strsplit(rules_csv, ",", -1);
  for (gint i = 0; parts[i] != nullptr; ++i) {
    g_strstrip(parts[i]);
    if (g_strcmp0(parts[i], rule_id) == 0) return TRUE;
  }
  return FALSE;
}

gchar* merge_rule_ids(const char* existing_csv, const char* rule_id, gboolean add) {
  g_autoptr(GPtrArray) ids = g_ptr_array_new_with_free_func(g_free);
  if (existing_csv != nullptr && existing_csv[0] != '\0') {
    g_auto(GStrv) parts = g_strsplit(existing_csv, ",", -1);
    for (gint i = 0; parts[i] != nullptr; ++i) {
      g_strstrip(parts[i]);
      if (parts[i][0] == '\0') continue;
      if (g_strcmp0(parts[i], rule_id) == 0) continue;
      g_ptr_array_add(ids, g_strdup(parts[i]));
    }
  }
  if (add) g_ptr_array_add(ids, g_strdup(rule_id));

  if (ids->len == 0) return g_strdup("");

  GString* merged = g_string_new(static_cast<const char*>(g_ptr_array_index(ids, 0)));
  for (guint i = 1; i < ids->len; ++i) {
    g_string_append_c(merged, ',');
    g_string_append(merged, static_cast<const char*>(g_ptr_array_index(ids, i)));
  }
  return g_string_free(merged, FALSE);
}

int count_csv_ids(const char* csv) {
  if (csv == nullptr || csv[0] == '\0') return 0;
  int count = 1;
  for (const char* p = csv; *p != '\0'; ++p) {
    if (*p == ',') count++;
  }
  return count;
}

gboolean write_pip_overlay_rule(gboolean enable) {
  g_autofree gchar* existing_rules = nullptr;
  if (!kreadconfig("General", "rules", &existing_rules)) {
    existing_rules = g_strdup("");
  }

  if (enable) {
    g_autofree gchar* merged = merge_rule_ids(existing_rules, kPipOverlayRuleId, TRUE);
    if (!kwriteconfig("General", "rules", merged)) return FALSE;
    if (!kwriteconfig_int("General", "count", count_csv_ids(merged))) return FALSE;

    if (!kwriteconfig(kPipOverlayRuleId, "Description", "Vitreous desktop PiP overlay layer")) return FALSE;
    if (!kwriteconfig(kPipOverlayRuleId, "wmclass", APPLICATION_ID)) return FALSE;
    if (!kwriteconfig_int(kPipOverlayRuleId, "wmclassmatch", kStringMatchSubstring)) return FALSE;
    if (!kwriteconfig_bool(kPipOverlayRuleId, "wmclasscomplete", FALSE)) return FALSE;
    if (!kwriteconfig_int(kPipOverlayRuleId, "types", 1)) return FALSE;
    if (!kwriteconfig_int(kPipOverlayRuleId, "layerrule", kLayerRuleForce)) return FALSE;
    if (!kwriteconfig_int(kPipOverlayRuleId, "layer", kLayerOverlay)) return FALSE;
    if (!kwriteconfig_bool(kPipOverlayRuleId, "enabled", TRUE)) return FALSE;
    if (!kwriteconfig_bool(kPipOverlayRuleId, "above", TRUE)) return FALSE;
    if (!kwriteconfig_int(kPipOverlayRuleId, "aboverule", kLayerRuleForce)) return FALSE;
  } else {
    if (!rule_id_listed(existing_rules, kPipOverlayRuleId)) return TRUE;
    g_autofree gchar* merged = merge_rule_ids(existing_rules, kPipOverlayRuleId, FALSE);
    if (!kwriteconfig("General", "rules", merged)) return FALSE;
    if (!kwriteconfig_int("General", "count", count_csv_ids(merged))) return FALSE;
    if (!kdelete_group(kPipOverlayRuleId)) return FALSE;
  }

  g_message("EmbyKWinOverlay: kwinrulesrc overlay rule %s (rules=%s)", enable ? "installed" : "removed",
            enable ? kPipOverlayRuleId : "removed");
  return TRUE;
}

gboolean kwin_dbus_call_void(GDBusConnection* conn, const char* path, const char* method,
                             GVariant* params) {
  GError* error = nullptr;
  g_autoptr(GVariant) result = g_dbus_connection_call_sync(
      conn, "org.kde.KWin", path, "org.kde.kwin.Script", method, params, nullptr,
      G_DBUS_CALL_FLAGS_NONE, 2000, nullptr, &error);
  if (error != nullptr) {
    g_message("EmbyKWinKeepAbove: %s failed: %s", method, error->message);
    g_error_free(error);
    return FALSE;
  }
  return TRUE;
}

gboolean kwin_dbus_call_scripting(GDBusConnection* conn, const char* method, GVariant* params,
                                  GVariant** out) {
  GError* error = nullptr;
  GVariant* result = g_dbus_connection_call_sync(
      conn, "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", method, params, nullptr,
      G_DBUS_CALL_FLAGS_NONE, 2000, nullptr, &error);
  if (error != nullptr) {
    g_message("EmbyKWinKeepAbove: Scripting.%s failed: %s", method, error->message);
    g_error_free(error);
    return FALSE;
  }
  if (out != nullptr) {
    *out = result;
  } else if (result != nullptr) {
    g_variant_unref(result);
  }
  return TRUE;
}

gboolean kwin_reconfigure(GDBusConnection* conn) {
  GError* error = nullptr;
  g_dbus_connection_call_sync(conn, "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure", nullptr,
                              nullptr, G_DBUS_CALL_FLAGS_NONE, 3000, nullptr, &error);
  if (error != nullptr) {
    g_message("EmbyKWinOverlay: reconfigure failed: %s", error->message);
    g_error_free(error);
    return FALSE;
  }
  return TRUE;
}

void run_keep_above_script(gint pid, gboolean keep_above) {
  if (pid <= 0) return;

  GError* error = nullptr;
  g_autoptr(GDBusConnection) conn = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (conn == nullptr) {
    g_message("EmbyKWinKeepAbove: session bus unavailable: %s", error ? error->message : "unknown");
    if (error) g_error_free(error);
    return;
  }

  const char* keep_literal = keep_above ? "true" : "false";
  g_autofree char* script = g_strdup_printf(
      "workspace.windowList().forEach(function(w){if(w.pid===%d){w.keepAbove=%s;workspace.raiseWindow(w);}});",
      pid, keep_literal);

  g_autofree char* script_path =
      g_build_filename(g_get_user_runtime_dir(), "vitreous-kwin-keepabove.js", nullptr);
  GError* write_error = nullptr;
  if (!g_file_set_contents(script_path, script, -1, &write_error)) {
    g_message("EmbyKWinKeepAbove: failed to write %s: %s", script_path,
              write_error ? write_error->message : "unknown");
    if (write_error) g_error_free(write_error);
    return;
  }

  g_autoptr(GVariant) load_result = nullptr;
  if (!kwin_dbus_call_scripting(conn, "loadScript", g_variant_new("(s)", script_path), &load_result)) {
    return;
  }

  gint script_id = -1;
  g_variant_get(load_result, "(i)", &script_id);
  if (script_id < 0) {
    g_message("EmbyKWinKeepAbove: loadScript returned invalid id %d", script_id);
    return;
  }

  g_autofree char* script_object_path = g_strdup_printf("/Scripting/Script%d", script_id);
  if (!kwin_dbus_call_void(conn, script_object_path, "run", nullptr)) {
    g_message("EmbyKWinKeepAbove: Script.run failed for %s", script_object_path);
    return;
  }

  g_message("EmbyKWinKeepAbove: KWin keepAbove=%d pid=%d (script %d)", keep_above, pid, script_id);
}

void run_log_layer_script(gint pid) {
  g_autofree char* script = g_strdup_printf(
      "workspace.windowList().forEach(function(w){"
      "if(w.pid===%d){"
      "print('EmbyKWinOverlay: window layer='+w.layer+' keepAbove='+w.keepAbove+' "
      "expectedOverlay=%d');"
      "if(w.layer!=%d)print('EmbyKWinOverlay: WARNING overlay layer not applied');"
      "}});",
      pid, kExpectedOverlayLayer, kExpectedOverlayLayer);
  g_autofree char* script_path =
      g_build_filename(g_get_user_runtime_dir(), "vitreous-kwin-log-layer.js", nullptr);
  if (!g_file_set_contents(script_path, script, -1, nullptr)) return;

  GError* error = nullptr;
  g_autoptr(GDBusConnection) conn = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (conn == nullptr) return;

  g_autoptr(GVariant) load_result = nullptr;
  if (!kwin_dbus_call_scripting(conn, "loadScript", g_variant_new("(s)", script_path), &load_result)) {
    return;
  }
  gint script_id = -1;
  g_variant_get(load_result, "(i)", &script_id);
  if (script_id < 0) return;
  g_autofree char* script_object_path = g_strdup_printf("/Scripting/Script%d", script_id);
  kwin_dbus_call_void(conn, script_object_path, "run", nullptr);
}

struct DeferredKdeKeepAbove {
  gboolean keep_above;
};

struct DeferredOverlayRematch {
  GtkWindow* window;
};

void rematch_window_for_rules(GtkWindow* window) {
  if (window == nullptr) return;
  GtkWidget* widget = GTK_WIDGET(window);
  if (!gtk_widget_get_visible(widget)) return;
  gtk_window_iconify(window);
  gtk_window_deiconify(window);
  gtk_window_present(window);
  g_message("EmbyKWinOverlay: iconify/deiconify rematch for window rules");
}

gboolean deferred_overlay_rematch_cb(gpointer user_data) {
  auto* data = static_cast<DeferredOverlayRematch*>(user_data);

  GError* error = nullptr;
  g_autoptr(GDBusConnection) conn = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (conn != nullptr) {
    kwin_reconfigure(conn);
  } else if (error != nullptr) {
    g_message("EmbyKWinOverlay: rematch reconfigure bus error: %s", error->message);
    g_error_free(error);
  }

  rematch_window_for_rules(data->window);
  run_keep_above_script(static_cast<gint>(getpid()), TRUE);
  run_log_layer_script(static_cast<gint>(getpid()));

  g_clear_object(&data->window);
  delete data;
  return G_SOURCE_REMOVE;
}

gboolean deferred_kde_keep_above_cb(gpointer user_data) {
  auto* data = static_cast<DeferredKdeKeepAbove*>(user_data);
  run_keep_above_script(static_cast<gint>(getpid()), data->keep_above);
  delete data;
  return G_SOURCE_REMOVE;
}

}  // namespace

gboolean emby_is_kde_session(void) {
  return env_contains_kde("XDG_CURRENT_DESKTOP") || env_contains_kde("XDG_SESSION_DESKTOP");
}

void emby_kde_kwin_set_keep_above(gboolean keep_above) {
  if (!emby_is_kde_session()) {
    g_message("EmbyKWinKeepAbove: skipped (not KDE session)");
    return;
  }
  run_keep_above_script(static_cast<gint>(getpid()), keep_above);
  if (keep_above) {
    auto* deferred = new DeferredKdeKeepAbove{keep_above};
    g_timeout_add(150, deferred_kde_keep_above_cb, deferred);
  }
}

void emby_kde_kwin_set_pip_overlay_layer(GtkWindow* window, gboolean enable) {
  if (!emby_is_kde_session()) {
    g_message("EmbyKWinOverlay: skipped (not KDE session)");
    return;
  }
  if (!write_pip_overlay_rule(enable)) return;

  GError* error = nullptr;
  g_autoptr(GDBusConnection) conn = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (conn == nullptr) {
    g_message("EmbyKWinOverlay: session bus unavailable: %s", error ? error->message : "unknown");
    if (error) g_error_free(error);
    return;
  }

  if (!kwin_reconfigure(conn)) return;

  if (enable) {
    rematch_window_for_rules(window);
    run_keep_above_script(static_cast<gint>(getpid()), TRUE);
    run_log_layer_script(static_cast<gint>(getpid()));

    if (window != nullptr) {
      auto* deferred = new DeferredOverlayRematch{};
      deferred->window = GTK_WINDOW(g_object_ref(window));
      g_timeout_add(450, deferred_overlay_rematch_cb, deferred);
    }
  } else if (window != nullptr) {
    rematch_window_for_rules(window);
  }

  g_message("EmbyKWinOverlay: pip overlay layer %s", enable ? "enabled (force)" : "disabled");
}
