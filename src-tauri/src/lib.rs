use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine as _};
use rand::{rngs::OsRng, RngCore};
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::{
    env,
    io::{BufRead, BufReader, Read, Write},
    net::TcpListener,
    path::{Path, PathBuf},
    process::{Child, Command, Stdio},
    sync::{Mutex, OnceLock},
    thread,
    time::{Duration, Instant},
};
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager, State,
};

#[cfg(target_os = "windows")]
use std::os::windows::process::CommandExt;

#[cfg(target_os = "windows")]
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

#[derive(Serialize)]
struct CommandResult {
    success: bool,
    message: String,
    detail: Option<String>,
}

impl CommandResult {
    fn ok(message: impl Into<String>) -> Self {
        Self {
            success: true,
            message: message.into(),
            detail: None,
        }
    }

    fn error(message: impl Into<String>) -> Self {
        Self {
            success: false,
            message: message.into(),
            detail: None,
        }
    }
}

#[derive(Serialize)]
struct SystemSnapshot {
    cpu_percent: f32,
    memory_percent: u32,
    memory_used_gb: f64,
    memory_total_gb: f64,
    computer_name: String,
}

#[derive(Serialize)]
struct VoiceDevice {
    id: i32,
    name: String,
    channels: u32,
    sample_rate: u32,
    is_default: bool,
}

#[derive(Default)]
struct VoiceState(Mutex<Option<Child>>);

const SPOTIFY_CLIENT_ID: &str = "f3ae5862a68248f399afc4afd78ca483";
const SPOTIFY_REDIRECT_URI: &str = "http://127.0.0.1:8888/callback";
const SPOTIFY_SCOPES: &str = "user-modify-playback-state user-read-playback-state playlist-read-private playlist-read-collaborative";

#[derive(Clone)]
struct SpotifySession {
    access_token: String,
    expires_at: Instant,
}

#[derive(Default)]
struct SpotifyState(Mutex<Option<SpotifySession>>);

#[derive(Clone, Serialize)]
struct SpotifyStatus {
    connected: bool,
    message: String,
}

fn hidden_command(program: impl AsRef<std::ffi::OsStr>) -> Command {
    let mut command = Command::new(program);
    #[cfg(target_os = "windows")]
    command.creation_flags(CREATE_NO_WINDOW);
    command
}

fn normalize(value: &str) -> String {
    value
        .trim()
        .to_lowercase()
        .replace(['á', 'à', 'ã', 'â', 'ä'], "a")
        .replace(['é', 'è', 'ê', 'ë'], "e")
        .replace(['í', 'ì', 'î', 'ï'], "i")
        .replace(['ó', 'ò', 'õ', 'ô', 'ö'], "o")
        .replace(['ú', 'ù', 'û', 'ü'], "u")
        .replace('ç', "c")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn validate_entity(entity: &str) -> Result<String, CommandResult> {
    let value = entity.trim();
    if value.is_empty() {
        return Err(CommandResult::error(
            "Faltou informar o nome do aplicativo ou conteúdo.",
        ));
    }
    if value.chars().count() > 160 || value.contains(['\r', '\n', '\0']) {
        return Err(CommandResult::error("O nome informado não é válido."));
    }
    Ok(value.to_string())
}

fn start_program(program: &Path, args: &[&str]) -> std::io::Result<()> {
    let mut command = hidden_command(program);
    command
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    command.spawn().map(|_| ())
}

fn start_named(program: &str, args: &[&str]) -> std::io::Result<()> {
    start_program(Path::new(program), args)
}

fn first_existing(candidates: Vec<PathBuf>) -> Option<PathBuf> {
    candidates.into_iter().find(|path| path.is_file())
}

fn env_path(variable: &str, suffix: &str) -> Option<PathBuf> {
    env::var_os(variable).map(|root| PathBuf::from(root).join(suffix))
}

fn known_app(target: &str) -> Option<(String, Vec<String>, String)> {
    let key = normalize(target);
    let direct = |program: &str, label: &str| {
        Some((program.to_string(), Vec::<String>::new(), label.to_string()))
    };

    match key.as_str() {
        "calculadora" | "calculator" | "calc" => direct("calc.exe", "Calculadora"),
        "bloco de notas" | "notepad" => direct("notepad.exe", "Bloco de Notas"),
        "paint" | "mspaint" => direct("mspaint.exe", "Paint"),
        "explorador" | "explorador de arquivos" | "arquivos" => {
            direct("explorer.exe", "Explorador de Arquivos")
        }
        "terminal" | "windows terminal" => direct("wt.exe", "Terminal"),
        "configuracoes" | "configuracao" | "settings" => Some((
            "explorer.exe".into(),
            vec!["ms-settings:".into()],
            "Configurações".into(),
        )),
        "edge" | "microsoft edge" => Some((
            "explorer.exe".into(),
            vec!["microsoft-edge:".into()],
            "Microsoft Edge".into(),
        )),
        "steam" | "istim" | "istime" | "stim" => Some((
            "explorer.exe".into(),
            vec!["steam://open/main".into()],
            "Steam".into(),
        )),
        "spotify" | "espotifai" | "spotifai" | "espotfai" | "spotfai" | "spotfy" | "espotify" => {
            let candidate = env_path("APPDATA", r"Spotify\Spotify.exe");
            if let Some(path) = candidate.filter(|path| path.is_file()) {
                Some((
                    path.to_string_lossy().into_owned(),
                    Vec::new(),
                    "Spotify".into(),
                ))
            } else {
                Some((
                    "explorer.exe".into(),
                    vec!["spotify:".into()],
                    "Spotify".into(),
                ))
            }
        }
        "chrome" | "google chrome" | "crome" | "cromi" => {
            let path = first_existing(
                [
                    env_path("PROGRAMFILES", r"Google\Chrome\Application\chrome.exe"),
                    env_path("PROGRAMFILES(X86)", r"Google\Chrome\Application\chrome.exe"),
                    env_path("LOCALAPPDATA", r"Google\Chrome\Application\chrome.exe"),
                ]
                .into_iter()
                .flatten()
                .collect(),
            )?;
            Some((
                path.to_string_lossy().into_owned(),
                Vec::new(),
                "Google Chrome".into(),
            ))
        }
        "firefox" | "mozilla firefox" => {
            let path = first_existing(
                [
                    env_path("PROGRAMFILES", r"Mozilla Firefox\firefox.exe"),
                    env_path("PROGRAMFILES(X86)", r"Mozilla Firefox\firefox.exe"),
                ]
                .into_iter()
                .flatten()
                .collect(),
            )?;
            Some((
                path.to_string_lossy().into_owned(),
                Vec::new(),
                "Mozilla Firefox".into(),
            ))
        }
        "discord" | "discorde" | "discordi" | "descorde" | "discordia" => {
            let update = env_path("LOCALAPPDATA", r"Discord\Update.exe")?;
            if !update.is_file() {
                return None;
            }
            Some((
                update.to_string_lossy().into_owned(),
                vec!["--processStart".into(), "Discord.exe".into()],
                "Discord".into(),
            ))
        }
        "visual studio code" | "vs code" | "vscode" | "code" => {
            let path = first_existing(
                [
                    env_path("LOCALAPPDATA", r"Programs\Microsoft VS Code\Code.exe"),
                    env_path("PROGRAMFILES", r"Microsoft VS Code\Code.exe"),
                ]
                .into_iter()
                .flatten()
                .collect(),
            )?;
            Some((
                path.to_string_lossy().into_owned(),
                Vec::new(),
                "Visual Studio Code".into(),
            ))
        }
        _ => None,
    }
}

#[cfg(target_os = "windows")]
fn find_start_app(query: &str) -> Option<(String, String)> {
    let script = r#"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$q = $env:FRIDAY_APP_QUERY
$app = Get-StartApps | Where-Object { $_.Name -like ('*' + $q + '*') } | Select-Object -First 1
if ($null -ne $app) {
  Write-Output $app.Name
  Write-Output $app.AppID
}
"#;
    let output = hidden_command("powershell.exe")
        .args([
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            script,
        ])
        .env("FRIDAY_APP_QUERY", query)
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut lines = stdout
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty());
    let name = lines.next()?.to_string();
    let app_id = lines.next()?.to_string();
    Some((name, app_id))
}

#[cfg(not(target_os = "windows"))]
fn find_start_app(_query: &str) -> Option<(String, String)> {
    None
}

fn launch_app(entity: &str) -> CommandResult {
    let target = match validate_entity(entity) {
        Ok(target) => target,
        Err(result) => return result,
    };

    if let Some((program, args, label)) = known_app(&target) {
        let borrowed = args.iter().map(String::as_str).collect::<Vec<_>>();
        return match start_named(&program, &borrowed) {
            Ok(()) => CommandResult::ok(format!("Abrindo {label}.")),
            Err(error) => CommandResult::error(format!("Não consegui abrir {label}: {error}")),
        };
    }

    if let Some((name, app_id)) = find_start_app(&target) {
        let shell_target = format!(r"shell:AppsFolder\{app_id}");
        return match start_named("explorer.exe", &[&shell_target]) {
            Ok(()) => CommandResult::ok(format!("Abrindo {name}.")),
            Err(error) => CommandResult::error(format!(
                "Encontrei {name}, mas o Windows não conseguiu abri-lo: {error}"
            )),
        };
    }

    CommandResult::error(format!("Não encontrei “{target}” entre os aplicativos instalados. Tente usar o nome exibido no menu Iniciar."))
}

fn percent_encode(value: &str) -> String {
    let mut encoded = String::new();
    for byte in value.as_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                encoded.push(*byte as char)
            }
            b' ' => encoded.push_str("%20"),
            _ => encoded.push_str(&format!("%{byte:02X}")),
        }
    }
    encoded
}

fn percent_decode(value: &str) -> String {
    let mut output = Vec::with_capacity(value.len());
    let bytes = value.as_bytes();
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' && index + 2 < bytes.len() {
            let hex = |byte: u8| match byte {
                b'0'..=b'9' => Some(byte - b'0'),
                b'a'..=b'f' => Some(byte - b'a' + 10),
                b'A'..=b'F' => Some(byte - b'A' + 10),
                _ => None,
            };
            if let (Some(high), Some(low)) = (hex(bytes[index + 1]), hex(bytes[index + 2])) {
                output.push(high * 16 + low);
                index += 3;
                continue;
            }
        }
        output.push(if bytes[index] == b'+' {
            b' '
        } else {
            bytes[index]
        });
        index += 1;
    }
    String::from_utf8_lossy(&output).into_owned()
}

fn query_value(query: &str, key: &str) -> Option<String> {
    query.split('&').find_map(|pair| {
        let (candidate, value) = pair.split_once('=')?;
        (candidate == key).then(|| percent_decode(value))
    })
}

fn random_url_value(bytes: usize) -> String {
    let mut buffer = vec![0_u8; bytes];
    OsRng.fill_bytes(&mut buffer);
    URL_SAFE_NO_PAD.encode(buffer)
}

fn spotify_session(state: &SpotifyState) -> Option<SpotifySession> {
    let mut session = state.0.lock().ok()?;
    match session.as_ref() {
        Some(current) if current.expires_at > Instant::now() + Duration::from_secs(20) => {
            Some(current.clone())
        }
        _ => {
            *session = None;
            None
        }
    }
}

fn spotify_exchange_code(
    app: AppHandle,
    state: &SpotifyState,
    code: &str,
    verifier: &str,
) -> Result<(), String> {
    let response = reqwest::blocking::Client::new()
        .post("https://accounts.spotify.com/api/token")
        .form(&[
            ("client_id", SPOTIFY_CLIENT_ID),
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", SPOTIFY_REDIRECT_URI),
            ("code_verifier", verifier),
        ])
        .send()
        .map_err(|error| format!("Não consegui falar com o Spotify: {error}"))?;
    let status = response.status();
    let body: serde_json::Value = response
        .json()
        .map_err(|error| format!("Resposta de autenticação inválida: {error}"))?;
    if !status.is_success() {
        return Err(format!(
            "O Spotify recusou a autorização: {}",
            body.get("error_description")
                .and_then(|value| value.as_str())
                .unwrap_or("verifique o Redirect URI cadastrado")
        ));
    }
    let token = body
        .get("access_token")
        .and_then(|value| value.as_str())
        .ok_or("O Spotify não devolveu um token de acesso.")?;
    let expires_in = body
        .get("expires_in")
        .and_then(|value| value.as_u64())
        .unwrap_or(3600);
    let mut stored = state
        .0
        .lock()
        .map_err(|_| "Sessão do Spotify indisponível.")?;
    *stored = Some(SpotifySession {
        access_token: token.to_owned(),
        expires_at: Instant::now() + Duration::from_secs(expires_in),
    });
    drop(stored);
    let _ = app.emit(
        "spotify-status",
        SpotifyStatus {
            connected: true,
            message: "Spotify conectado. Agora posso tocar músicas e playlists diretamente.".into(),
        },
    );
    Ok(())
}

#[tauri::command]
fn spotify_status(state: State<'_, SpotifyState>) -> SpotifyStatus {
    if spotify_session(&state).is_some() {
        SpotifyStatus {
            connected: true,
            message: "Spotify conectado nesta sessão.".into(),
        }
    } else {
        SpotifyStatus {
            connected: false,
            message: "Conecte sua conta do Spotify para reprodução direta.".into(),
        }
    }
}

#[tauri::command]
fn spotify_connect(app: AppHandle) -> CommandResult {
    let listener = match TcpListener::bind("127.0.0.1:8888") {
        Ok(listener) => listener,
        Err(_) => return CommandResult::error("Não consegui reservar a porta de login do Spotify. Feche outro programa que use a porta 8888 e tente novamente."),
    };
    let verifier = random_url_value(64);
    let challenge = URL_SAFE_NO_PAD.encode(Sha256::digest(verifier.as_bytes()));
    let request_state = random_url_value(24);
    let authorize_url = format!(
        "https://accounts.spotify.com/authorize?response_type=code&client_id={}&redirect_uri={}&scope={}&state={}&code_challenge_method=S256&code_challenge={}",
        SPOTIFY_CLIENT_ID,
        percent_encode(SPOTIFY_REDIRECT_URI),
        percent_encode(SPOTIFY_SCOPES),
        request_state,
        challenge,
    );
    // explorer.exe pode interpretar uma URL longa como caminho de pasta. O
    // manipulador de protocolo do Windows encaminha a URL ao navegador padrão.
    if let Err(error) = start_named(
        "rundll32.exe",
        &["url.dll,FileProtocolHandler", &authorize_url],
    ) {
        return CommandResult::error(format!(
            "Não consegui abrir o navegador para o login: {error}"
        ));
    }
    let event_app = app.clone();
    thread::spawn(move || {
        let _ = listener.set_nonblocking(true);
        let deadline = Instant::now() + Duration::from_secs(180);
        while Instant::now() < deadline {
            match listener.accept() {
                Ok((mut stream, _)) => {
                    let mut request = [0_u8; 8192];
                    let read = stream.read(&mut request).unwrap_or(0);
                    let line = String::from_utf8_lossy(&request[..read])
                        .lines()
                        .next()
                        .unwrap_or("")
                        .to_owned();
                    let query = line
                        .split_whitespace()
                        .nth(1)
                        .and_then(|path| path.split_once('?').map(|(_, query)| query))
                        .unwrap_or("");
                    let code = query_value(query, "code");
                    let returned_state = query_value(query, "state");
                    let result = match (code, returned_state) {
                        (Some(code), Some(returned_state)) if returned_state == request_state => spotify_exchange_code(event_app.clone(), &event_app.state::<SpotifyState>(), &code, &verifier),
                        _ => Err("A autorização foi cancelada ou não passou na verificação de segurança.".into()),
                    };
                    let page = if result.is_ok() {
                        "<h2>Spotify conectado.</h2><p>Você já pode fechar esta aba e voltar ao F.R.I.D.A.Y.</p>"
                    } else {
                        "<h2>Não foi possível conectar o Spotify.</h2><p>Volte ao F.R.I.D.A.Y. e tente novamente.</p>"
                    };
                    let response = format!("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n{page}");
                    let _ = stream.write_all(response.as_bytes());
                    if let Err(message) = result {
                        let _ = event_app.emit(
                            "spotify-status",
                            SpotifyStatus {
                                connected: false,
                                message,
                            },
                        );
                    }
                    return;
                }
                Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                    thread::sleep(Duration::from_millis(100))
                }
                Err(_) => break,
            }
        }
        let _ = event_app.emit(
            "spotify-status",
            SpotifyStatus {
                connected: false,
                message: "O tempo para autorizar o Spotify expirou.".into(),
            },
        );
    });
    CommandResult::ok("Abri o navegador para conectar sua conta do Spotify.")
}

fn google_search(entity: &str) -> CommandResult {
    let query = match validate_entity(entity) {
        Ok(query) => query,
        Err(_) => return CommandResult::error("Diga o que você quer pesquisar no Google."),
    };
    let url = format!("https://www.google.com/search?q={}", percent_encode(&query));
    match start_named("explorer.exe", &[&url]) {
        Ok(()) => CommandResult::ok(format!("Pesquisando “{query}” no Google.")),
        Err(error) => CommandResult::error(format!("Não consegui abrir o navegador: {error}")),
    }
}

fn spotify_search(entity: &str, playlist: bool) -> CommandResult {
    let query = match validate_entity(entity) {
        Ok(query) => query,
        Err(_) => {
            return CommandResult::error("Diga qual música, artista ou playlist você quer ouvir.")
        }
    };
    let direct_resource = query.starts_with("spotify:")
        || query.starts_with("https://open.spotify.com/")
        || query.starts_with("http://open.spotify.com/");
    let uri = if direct_resource {
        query.clone()
    } else {
        let search = if playlist {
            format!("playlist {query}")
        } else {
            query.clone()
        };
        format!("spotify:search:{}", percent_encode(&search))
    };
    match start_named("explorer.exe", &[&uri]) {
        Ok(()) if direct_resource => {
            CommandResult::ok(format!("Abrindo “{query}” diretamente no Spotify."))
        }
        Ok(()) if playlist => CommandResult::ok(format!(
            "Abrindo as playlists de “{query}” no Spotify. Se houver mais de uma com esse nome, escolha a primeira vez e depois ela ficará fácil de acessar novamente."
        )),
        Ok(()) => CommandResult::ok(format!(
            "Abrindo “{query}” no Spotify. O aplicativo mostra primeiro o resultado mais compatível para você tocar."
        )),
        Err(error) => CommandResult::error(format!("Não consegui abrir o Spotify: {error}")),
    }
}

fn spotify_play_from_catalog(
    state: &SpotifyState,
    entity: &str,
    playlist: bool,
) -> Option<CommandResult> {
    let session = spotify_session(state)?;
    let query = validate_entity(entity).ok()?;
    let item_type = if playlist { "playlist" } else { "track" };
    let url = format!(
        "https://api.spotify.com/v1/search?q={}&type={item_type}&limit=1",
        percent_encode(&query)
    );
    let client = reqwest::blocking::Client::new();
    let response = match client.get(url).bearer_auth(&session.access_token).send() {
        Ok(response) => response,
        Err(error) => {
            return Some(CommandResult::error(format!(
                "Não consegui pesquisar no Spotify: {error}"
            )))
        }
    };
    if response.status() == reqwest::StatusCode::UNAUTHORIZED {
        if let Ok(mut stored) = state.0.lock() {
            *stored = None;
        }
        return Some(CommandResult::error(
            "A conexão com Spotify expirou. Clique em “Conectar Spotify” novamente.",
        ));
    }
    if !response.status().is_success() {
        return Some(CommandResult::error(
            "O Spotify não conseguiu pesquisar esse item.",
        ));
    }
    let body: serde_json::Value = match response.json() {
        Ok(body) => body,
        Err(_) => {
            return Some(CommandResult::error(
                "A resposta do Spotify não pôde ser lida.",
            ))
        }
    };
    let collection = if playlist { "playlists" } else { "tracks" };
    let item = match body.pointer(&format!("/{collection}/items/0")) {
        Some(item) => item,
        None => {
            return Some(CommandResult::error(format!(
                "Não encontrei “{query}” no Spotify."
            )))
        }
    };
    let uri = match item.get("uri").and_then(|value| value.as_str()) {
        Some(uri) => uri,
        None => {
            return Some(CommandResult::error(
                "O Spotify não devolveu um item reproduzível.",
            ))
        }
    };
    let name = item
        .get("name")
        .and_then(|value| value.as_str())
        .unwrap_or(&query);
    let payload = if playlist {
        serde_json::json!({ "context_uri": uri })
    } else {
        serde_json::json!({ "uris": [uri] })
    };
    let playback = match client
        .put("https://api.spotify.com/v1/me/player/play")
        .bearer_auth(&session.access_token)
        .json(&payload)
        .send()
    {
        Ok(response) => response,
        Err(error) => {
            return Some(CommandResult::error(format!(
                "Não consegui iniciar a reprodução: {error}"
            )))
        }
    };
    match playback.status() {
        status if status.is_success() => Some(CommandResult::ok(format!("Tocando “{name}” no Spotify."))),
        reqwest::StatusCode::NOT_FOUND => Some(CommandResult::error("Abri o Spotify, mas ele ainda não apareceu como dispositivo ativo. Deixe o Spotify aberto e tente novamente.")),
        reqwest::StatusCode::FORBIDDEN => Some(CommandResult::error("O Spotify recusou a reprodução. Esse recurso exige uma conta Premium e um dispositivo Spotify ativo.")),
        _ => Some(CommandResult::error("O Spotify não conseguiu iniciar a reprodução.")),
    }
}

fn process_alias(target: &str) -> Option<&'static str> {
    match normalize(target).as_str() {
        "chrome" | "google chrome" | "crome" | "cromi" => Some("chrome.exe"),
        "edge" | "microsoft edge" => Some("msedge.exe"),
        "firefox" | "mozilla firefox" => Some("firefox.exe"),
        "spotify" | "espotifai" | "spotifai" | "espotfai" | "spotfai" | "spotfy" | "espotify" => {
            Some("Spotify.exe")
        }
        "discord" | "discorde" | "discordi" | "descorde" | "discordia" => Some("Discord.exe"),
        "steam" | "istim" | "istime" | "stim" => Some("steam.exe"),
        "visual studio code" | "vs code" | "vscode" | "code" => Some("Code.exe"),
        "bloco de notas" | "notepad" => Some("notepad.exe"),
        "calculadora" | "calculator" | "calc" => Some("CalculatorApp.exe"),
        "paint" | "mspaint" => Some("mspaint.exe"),
        "terminal" | "windows terminal" => Some("WindowsTerminal.exe"),
        _ => None,
    }
}

fn parse_csv_first_field(line: &str) -> Option<String> {
    let trimmed = line.trim();
    if !trimmed.starts_with('"') {
        return trimmed
            .split(',')
            .next()
            .map(|value| value.trim().to_string());
    }
    let remainder = &trimmed[1..];
    let end = remainder.find('"')?;
    Some(remainder[..end].to_string())
}

fn close_app(entity: &str) -> CommandResult {
    let target = match validate_entity(entity) {
        Ok(target) => target,
        Err(result) => return result,
    };
    let normalized_target = normalize(&target);
    let critical = [
        "system",
        "registry",
        "smss",
        "csrss",
        "wininit",
        "services",
        "lsass",
        "winlogon",
        "svchost",
        "dwm",
        "explorer",
        "taskhostw",
        "friday",
        "friday core",
    ];
    if critical.contains(&normalized_target.as_str()) || normalized_target.len() < 3 {
        return CommandResult::error(
            "Esse processo é crítico ou o nome é curto demais; o encerramento foi bloqueado.",
        );
    }

    let requested_image = process_alias(&target).map(str::to_string);
    let output = match hidden_command("tasklist.exe")
        .args(["/FO", "CSV", "/NH"])
        .output()
    {
        Ok(output) => output,
        Err(error) => {
            return CommandResult::error(format!(
                "Não consegui consultar os aplicativos abertos: {error}"
            ))
        }
    };
    let stdout = String::from_utf8_lossy(&output.stdout);
    let matched_image = stdout
        .lines()
        .filter_map(parse_csv_first_field)
        .find(|image| {
            if let Some(expected) = &requested_image {
                image.eq_ignore_ascii_case(expected)
            } else {
                let stem = Path::new(image)
                    .file_stem()
                    .and_then(|value| value.to_str())
                    .unwrap_or(image);
                let normalized_stem = normalize(stem);
                normalized_stem == normalized_target
                    || (normalized_target.len() >= 5
                        && normalized_stem.contains(&normalized_target))
            }
        });

    let image = match matched_image {
        Some(image) => image,
        None => return CommandResult::error(format!("Não encontrei “{target}” em execução.")),
    };
    let normalized_image = normalize(
        Path::new(&image)
            .file_stem()
            .and_then(|value| value.to_str())
            .unwrap_or(&image),
    );
    if critical.contains(&normalized_image.as_str()) {
        return CommandResult::error(
            "O Windows marcou esse processo como crítico; o encerramento foi bloqueado.",
        );
    }

    let status = hidden_command("taskkill.exe")
        .args(["/IM", &image])
        .status();
    match status {
        Ok(code) if code.success() => CommandResult::ok(format!("{target} foi fechado.")),
        Ok(_) => CommandResult::error(format!("O Windows não permitiu fechar {target}. Talvez o aplicativo precise ser fechado manualmente.")),
        Err(error) => CommandResult::error(format!("Não consegui fechar {target}: {error}")),
    }
}

#[cfg(target_os = "windows")]
#[link(name = "user32")]
extern "system" {
    fn keybd_event(virtual_key: u8, scan_code: u8, flags: u32, extra_info: usize);
}

#[cfg(target_os = "windows")]
fn press_media_key(key: u8, times: u32) {
    for _ in 0..times {
        unsafe {
            keybd_event(key, 0, 0, 0);
            keybd_event(key, 0, 2, 0);
        }
    }
}

#[cfg(not(target_os = "windows"))]
fn press_media_key(_key: u8, _times: u32) {}

fn media_action(intent: &str, entity: &str) -> CommandResult {
    match intent {
        "media_play_pause" => {
            press_media_key(0xB3, 1);
            CommandResult::ok("Play/pause acionado.")
        }
        "media_next" => {
            press_media_key(0xB0, 1);
            CommandResult::ok("Avançando para a próxima faixa.")
        }
        "media_previous" => {
            press_media_key(0xB1, 1);
            CommandResult::ok("Voltando para a faixa anterior.")
        }
        "volume_up" => {
            press_media_key(0xAF, 3);
            CommandResult::ok("Volume aumentado.")
        }
        "volume_down" => {
            press_media_key(0xAE, 3);
            CommandResult::ok("Volume reduzido.")
        }
        "volume_mute" => {
            press_media_key(0xAD, 1);
            CommandResult::ok("Mudo alternado.")
        }
        "volume_set" => {
            let level = entity.parse::<u32>().unwrap_or(50).min(100);
            press_media_key(0xAE, 50);
            press_media_key(0xAF, (level + 1) / 2);
            CommandResult::ok(format!("Volume ajustado para aproximadamente {level}%."))
        }
        _ => CommandResult::error("Comando de mídia desconhecido."),
    }
}

#[tauri::command]
fn execute_intent(
    intent: String,
    entity: String,
    spotify: State<'_, SpotifyState>,
) -> CommandResult {
    match intent.as_str() {
        "open_app" => launch_app(&entity),
        "close_app" => close_app(&entity),
        "spotify_search" => spotify_play_from_catalog(&spotify, &entity, false)
            .unwrap_or_else(|| spotify_search(&entity, false)),
        "spotify_playlist" => spotify_play_from_catalog(&spotify, &entity, true)
            .unwrap_or_else(|| spotify_search(&entity, true)),
        "web_search" => google_search(&entity),
        "media_play_pause" | "media_next" | "media_previous" | "volume_up" | "volume_down"
        | "volume_mute" | "volume_set" => media_action(&intent, &entity),
        _ => CommandResult::error("Essa intenção não está autorizada no núcleo local."),
    }
}

#[cfg(target_os = "windows")]
#[repr(C)]
#[derive(Clone, Copy, Default)]
struct FileTime {
    low: u32,
    high: u32,
}

#[cfg(target_os = "windows")]
#[repr(C)]
struct MemoryStatusEx {
    length: u32,
    memory_load: u32,
    total_phys: u64,
    avail_phys: u64,
    total_page_file: u64,
    avail_page_file: u64,
    total_virtual: u64,
    avail_virtual: u64,
    avail_extended_virtual: u64,
}

#[cfg(target_os = "windows")]
#[link(name = "kernel32")]
extern "system" {
    fn GetSystemTimes(idle: *mut FileTime, kernel: *mut FileTime, user: *mut FileTime) -> i32;
    fn GlobalMemoryStatusEx(status: *mut MemoryStatusEx) -> i32;
}

#[cfg(target_os = "windows")]
fn file_time_value(value: FileTime) -> u64 {
    ((value.high as u64) << 32) | value.low as u64
}

#[cfg(target_os = "windows")]
fn windows_snapshot() -> (f32, u32, f64, f64) {
    static PREVIOUS_CPU: OnceLock<Mutex<Option<(u64, u64)>>> = OnceLock::new();
    let mut idle = FileTime::default();
    let mut kernel = FileTime::default();
    let mut user = FileTime::default();
    let mut cpu_percent = 0.0;

    if unsafe { GetSystemTimes(&mut idle, &mut kernel, &mut user) } != 0 {
        let idle_ticks = file_time_value(idle);
        let total_ticks = file_time_value(kernel) + file_time_value(user);
        let state = PREVIOUS_CPU.get_or_init(|| Mutex::new(None));
        if let Ok(mut previous) = state.lock() {
            if let Some((previous_idle, previous_total)) = *previous {
                let total_delta = total_ticks.saturating_sub(previous_total);
                let idle_delta = idle_ticks.saturating_sub(previous_idle);
                if total_delta > 0 {
                    cpu_percent = (100.0 * (total_delta.saturating_sub(idle_delta)) as f64
                        / total_delta as f64) as f32;
                }
            }
            *previous = Some((idle_ticks, total_ticks));
        }
    }

    let mut memory = MemoryStatusEx {
        length: std::mem::size_of::<MemoryStatusEx>() as u32,
        memory_load: 0,
        total_phys: 0,
        avail_phys: 0,
        total_page_file: 0,
        avail_page_file: 0,
        total_virtual: 0,
        avail_virtual: 0,
        avail_extended_virtual: 0,
    };
    if unsafe { GlobalMemoryStatusEx(&mut memory) } == 0 {
        return (cpu_percent, 0, 0.0, 0.0);
    }
    let divisor = 1024.0 * 1024.0 * 1024.0;
    let total_gb = memory.total_phys as f64 / divisor;
    let used_gb = memory.total_phys.saturating_sub(memory.avail_phys) as f64 / divisor;
    (cpu_percent, memory.memory_load, used_gb, total_gb)
}

#[cfg(not(target_os = "windows"))]
fn windows_snapshot() -> (f32, u32, f64, f64) {
    (0.0, 0, 0.0, 0.0)
}

#[tauri::command]
fn system_snapshot() -> SystemSnapshot {
    let (cpu_percent, memory_percent, memory_used_gb, memory_total_gb) = windows_snapshot();
    SystemSnapshot {
        cpu_percent,
        memory_percent,
        memory_used_gb,
        memory_total_gb,
        computer_name: env::var("COMPUTERNAME").unwrap_or_else(|_| "Computador local".into()),
    }
}

fn voice_assets(app: &AppHandle) -> Result<(PathBuf, PathBuf), String> {
    let bundled_root = app
        .path()
        .resource_dir()
        .map_err(|error| format!("Não foi possível localizar os recursos: {error}"))?
        .join("voice");
    let bundled_worker = bundled_root.join("voice-worker.exe");
    // O WiX preserva o nome original do arquivo mesmo quando um nome de destino
    // é informado no mapa de recursos. Aceitamos os dois nomes para que MSI e
    // NSIS usem exatamente o mesmo núcleo de voz.
    for archive_name in ["model.zip", "vosk-model-small-pt-0.3.zip"] {
        let bundled_archive = bundled_root.join(archive_name);
        if bundled_worker.is_file() && bundled_archive.is_file() {
            return Ok((bundled_worker.clone(), bundled_archive));
        }
    }

    // Compatibilidade com builds de desenvolvimento e pacotes antigos.
    let bundled_model = bundled_root.join("model");
    if bundled_worker.is_file() && bundled_model.join("final.mdl").is_file() {
        return Ok((bundled_worker, bundled_model));
    }

    let source_root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap_or_else(|| Path::new("."))
        .join("voice");
    let source_worker = source_root.join("bin").join("voice-worker.exe");
    let source_model = source_root.join("model");
    if source_worker.is_file() && source_model.join("final.mdl").is_file() {
        return Ok((source_worker, source_model));
    }

    Err("O módulo de voz não está instalado. Execute voice/build_voice.ps1 e gere o aplicativo novamente.".into())
}

fn stop_voice_child(state: &VoiceState) -> bool {
    let Ok(mut process) = state.0.lock() else {
        return false;
    };
    if let Some(mut child) = process.take() {
        let _ = child.kill();
        let _ = child.wait();
        return true;
    }
    false
}

#[tauri::command]
fn voice_devices(app: AppHandle) -> Result<Vec<VoiceDevice>, String> {
    let (worker, _) = voice_assets(&app)?;
    let output = hidden_command(worker)
        .arg("--list-devices")
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .map_err(|error| format!("Não consegui consultar os microfones: {error}"))?;
    if !output.status.success() {
        return Err("O módulo de voz não conseguiu consultar os microfones.".into());
    }

    for line in String::from_utf8_lossy(&output.stdout).lines() {
        let Ok(event) = serde_json::from_str::<serde_json::Value>(line) else {
            continue;
        };
        if event.get("type").and_then(|value| value.as_str()) != Some("devices") {
            continue;
        }
        let devices = event
            .get("devices")
            .and_then(|value| value.as_array())
            .into_iter()
            .flatten()
            .filter_map(|device| {
                Some(VoiceDevice {
                    id: i32::try_from(device.get("id")?.as_i64()?).ok()?,
                    name: device.get("name")?.as_str()?.to_owned(),
                    channels: u32::try_from(device.get("channels")?.as_u64()?).ok()?,
                    sample_rate: u32::try_from(device.get("sample_rate")?.as_u64()?).ok()?,
                    is_default: device.get("is_default")?.as_bool().unwrap_or(false),
                })
            })
            .collect::<Vec<_>>();
        return Ok(devices);
    }
    Err("O módulo de voz retornou uma lista de microfones inválida.".into())
}

#[tauri::command]
fn voice_start(
    app: AppHandle,
    state: State<'_, VoiceState>,
    device_id: Option<i32>,
) -> CommandResult {
    let mut process = match state.0.lock() {
        Ok(process) => process,
        Err(_) => {
            return CommandResult::error(
                "O controle do microfone está temporariamente indisponível.",
            )
        }
    };

    if let Some(child) = process.as_mut() {
        match child.try_wait() {
            Ok(None) => return CommandResult::ok("Já estou ouvindo a palavra “Sexta-feira”."),
            _ => {
                let _ = process.take();
            }
        }
    }

    let (worker, model) = match voice_assets(&app) {
        Ok(paths) => paths,
        Err(message) => return CommandResult::error(message),
    };
    let mut command = hidden_command(&worker);
    command
        .arg("--model")
        .arg(&model)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null());
    if let Some(device_id) = device_id {
        command.arg("--device").arg(device_id.to_string());
    }
    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(error) => {
            return CommandResult::error(format!(
                "Não consegui iniciar o reconhecimento de voz: {error}"
            ))
        }
    };
    let stdout = match child.stdout.take() {
        Some(stdout) => stdout,
        None => {
            let _ = child.kill();
            return CommandResult::error("O canal do reconhecimento de voz não pôde ser aberto.");
        }
    };
    *process = Some(child);
    drop(process);

    let event_app = app.clone();
    thread::spawn(move || {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            let Ok(event) = serde_json::from_str::<serde_json::Value>(&line) else {
                continue;
            };
            match event.get("type").and_then(|value| value.as_str()) {
                Some("ready") => {
                    let message = event
                        .get("message")
                        .and_then(|value| value.as_str())
                        .unwrap_or("Ouvindo a palavra Sexta-feira.");
                    let _ = event_app.emit("voice-status", message);
                    if let Some(device) = event.get("device").and_then(|value| value.as_str()) {
                        let _ = event_app.emit("voice-device", device);
                    }
                }
                Some("level") => {
                    if let Some(value) = event.get("value").and_then(|value| value.as_u64()) {
                        let _ = event_app.emit("voice-level", value.min(100));
                    }
                }
                Some("partial") => {
                    if let Some(text) = event.get("text").and_then(|value| value.as_str()) {
                        let _ = event_app.emit("voice-partial", text);
                    }
                }
                Some("transcript") => {
                    if let Some(text) = event.get("text").and_then(|value| value.as_str()) {
                        let _ = event_app.emit("voice-transcript", text);
                    }
                }
                Some("warning") => {
                    if let Some(message) = event.get("message").and_then(|value| value.as_str()) {
                        let _ = event_app.emit("voice-warning", message);
                    }
                }
                Some("error") => {
                    let message = event
                        .get("message")
                        .and_then(|value| value.as_str())
                        .unwrap_or("Falha desconhecida no reconhecimento de voz.");
                    let _ = event_app.emit("voice-error", message);
                }
                _ => {}
            }
        }
        let _ = event_app.emit("voice-stopped", "Reconhecimento de voz encerrado.");
    });

    CommandResult::ok("Iniciando o microfone local. Diga “Sexta-feira” antes do comando.")
}

#[tauri::command]
fn voice_stop(state: State<'_, VoiceState>) -> CommandResult {
    if stop_voice_child(&state) {
        CommandResult::ok("Microfone desativado.")
    } else {
        CommandResult::ok("O microfone já estava desativado.")
    }
}

#[tauri::command]
fn voice_is_active(state: State<'_, VoiceState>) -> bool {
    let Ok(mut process) = state.0.lock() else {
        return false;
    };
    let Some(child) = process.as_mut() else {
        return false;
    };
    matches!(child.try_wait(), Ok(None))
}

#[tauri::command]
fn cmd_minimize(window: tauri::WebviewWindow) {
    let _ = window.minimize();
}

#[tauri::command]
fn cmd_maximize(window: tauri::WebviewWindow) {
    if window.is_maximized().unwrap_or(false) {
        let _ = window.unmaximize();
    } else {
        let _ = window.maximize();
    }
}

#[tauri::command]
fn cmd_close(window: tauri::WebviewWindow) {
    let _ = window.hide();
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(VoiceState::default())
        .manage(SpotifyState::default())
        .setup(|app| {
            let show = MenuItem::with_id(app, "show", "Mostrar F.R.I.D.A.Y.", true, None::<&str>)?;
            let hide = MenuItem::with_id(app, "hide", "Ocultar", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Encerrar", true, None::<&str>)?;
            let separator = tauri::menu::PredefinedMenuItem::separator(app)?;
            let menu = Menu::with_items(app, &[&show, &hide, &separator, &quit])?;

            let _tray = TrayIconBuilder::new()
                .menu(&menu)
                .tooltip("F.R.I.D.A.Y. Local")
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => {
                        let state = app.state::<VoiceState>();
                        stop_voice_child(&state);
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
                        if let Some(window) = tray.app_handle().get_webview_window("main") {
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            execute_intent,
            system_snapshot,
            spotify_status,
            spotify_connect,
            voice_devices,
            voice_start,
            voice_stop,
            voice_is_active,
            cmd_minimize,
            cmd_maximize,
            cmd_close
        ])
        .run(tauri::generate_context!())
        .expect("Falha ao iniciar F.R.I.D.A.Y. Local");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_portuguese_app_names() {
        assert_eq!(normalize("  Configurações  "), "configuracoes");
        assert_eq!(normalize("MÚSICA   e Áudio"), "musica e audio");
    }

    #[test]
    fn encodes_search_terms_without_external_library() {
        assert_eq!(
            percent_encode("São Paulo & café"),
            "S%C3%A3o%20Paulo%20%26%20caf%C3%A9"
        );
    }

    #[test]
    fn parses_windows_task_list_rows() {
        let row = r#""chrome.exe","1234","Console","1","120.000 K""#;
        assert_eq!(parse_csv_first_field(row).as_deref(), Some("chrome.exe"));
    }

    #[test]
    fn maps_only_known_process_aliases() {
        assert_eq!(process_alias("Google Chrome"), Some("chrome.exe"));
        assert_eq!(process_alias("aplicativo inventado"), None);
    }

    #[test]
    fn rejects_empty_and_multiline_entities() {
        assert!(validate_entity("").is_err());
        assert!(validate_entity("calc\n.exe").is_err());
    }
}
