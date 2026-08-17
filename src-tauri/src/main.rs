// F.R.I.D.A.Y. — Tauri v2 Entry Point
// Janela nativa sem bordas, transparente, com system tray.
// O frontend (index.html) é carregado como webview.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager, Runtime,
};

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            // ── System Tray ────────────────────────────────────────────
            let quit   = MenuItem::with_id(app, "quit",    "Encerrar F.R.I.D.A.Y.", true, None::<&str>)?;
            let hide   = MenuItem::with_id(app, "hide",    "Minimizar",             true, None::<&str>)?;
            let show   = MenuItem::with_id(app, "show",    "Mostrar",               true, None::<&str>)?;
            let sep    = tauri::menu::PredefinedMenuItem::separator(app)?;

            let menu = Menu::with_items(app, &[&show, &hide, &sep, &quit])?;

            let _tray = TrayIconBuilder::new()
                .menu(&menu)
                .tooltip("F.R.I.D.A.Y. — Hub Online")
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => {
                        app.exit(0);
                    }
                    "hide" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.hide();
                        }
                    }
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            Ok(())
        })
        // ── Comandos Tauri expostos ao frontend via invoke() ──────────
        .invoke_handler(tauri::generate_handler![
            cmd_minimize,
            cmd_maximize,
            cmd_close,
            cmd_toggle_fullscreen,
        ])
        .run(tauri::generate_context!())
        .expect("Falha ao iniciar F.R.I.D.A.Y.");
}

// ── Comandos invocáveis pelo JavaScript do frontend ────────────────────────

#[tauri::command]
async fn cmd_minimize(window: tauri::WebviewWindow) {
    let _ = window.minimize();
}

#[tauri::command]
async fn cmd_maximize(window: tauri::WebviewWindow) {
    if window.is_maximized().unwrap_or(false) {
        let _ = window.unmaximize();
    } else {
        let _ = window.maximize();
    }
}

#[tauri::command]
async fn cmd_close(window: tauri::WebviewWindow) {
    let _ = window.hide();   // Minimiza para tray em vez de fechar
}

#[tauri::command]
async fn cmd_toggle_fullscreen(window: tauri::WebviewWindow) {
    let is_fs = window.is_fullscreen().unwrap_or(false);
    let _ = window.set_fullscreen(!is_fs);
}
