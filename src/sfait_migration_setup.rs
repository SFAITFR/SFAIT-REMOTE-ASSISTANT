#![cfg_attr(all(not(debug_assertions), target_os = "windows"), windows_subsystem = "windows")]

use std::{
    env,
    ffi::OsStr,
    fs,
    io::Write,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    thread,
    time::Duration,
};

use reqwest::blocking::Client;
use serde::Deserialize;

const APP_NAME: &str = "SFAIT Remote Assistant";
const APP_EXE_NAME: &str = "SFAIT Remote Assistant.exe";
const LEGACY_UNINSTALLER_NAME: &str = "unins000.exe";
const WINDOWS_INSTALLER_ASSET: &str = "SFAIT_Remote_Assistant_installer.msi";
const GITHUB_API_URL: &str = "https://api.github.com/repos/SFAITFR/SFAIT-REMOTE-ASSISTANT/releases/latest";

#[derive(Debug, Deserialize)]
struct ReleaseAsset {
    name: String,
    browser_download_url: String,
}

#[derive(Debug, Deserialize)]
struct ReleaseResponse {
    tag_name: String,
    assets: Vec<ReleaseAsset>,
}

fn main() {
    if let Err(err) = run() {
        log_line(&format!("Migration failed: {err}"));
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    log_line("Starting legacy Windows migration setup.");
    let temp_dir = env::temp_dir().join("SFAIT-Remote-Assistant-Migration");
    fs::create_dir_all(&temp_dir).map_err(|e| format!("create temp dir: {e}"))?;

    kill_process("Update_agent.exe");
    kill_process(APP_EXE_NAME);
    kill_process("rustdesk.exe");

    let legacy_install_dir = program_files_dir().join(APP_NAME);
    let legacy_uninstaller = legacy_install_dir.join(LEGACY_UNINSTALLER_NAME);
    if legacy_uninstaller.exists() {
        log_line(&format!(
            "Running legacy uninstaller: {}",
            legacy_uninstaller.display()
        ));
        run_command(
            &legacy_uninstaller,
            &["/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"],
        )?;
    } else {
        log_line("Legacy uninstaller not found; continuing with manual cleanup.");
    }

    remove_path_with_retries(&legacy_install_dir);
    remove_path_with_retries(&roaming_appdata_dir().join(APP_NAME));
    remove_path_with_retries(&roaming_appdata_dir().join("RustDesk").join("config"));
    remove_path_with_retries(
        &program_data_dir()
            .join("Microsoft")
            .join("Windows")
            .join("Start Menu")
            .join("Programs")
            .join(format!("{APP_NAME}.lnk")),
    );
    remove_path_with_retries(
        &public_dir()
            .join("Desktop")
            .join(format!("{APP_NAME}.lnk")),
    );

    let release = fetch_latest_release()?;
    log_line(&format!("Latest GitHub release detected: {}", release.tag_name));
    let installer_asset = release
        .assets
        .iter()
        .find(|asset| asset.name.eq_ignore_ascii_case(WINDOWS_INSTALLER_ASSET))
        .ok_or_else(|| format!("missing asset {WINDOWS_INSTALLER_ASSET}"))?;

    let installer_path = temp_dir.join(WINDOWS_INSTALLER_ASSET);
    download_file(&installer_asset.browser_download_url, &installer_path)?;
    log_line(&format!(
        "Downloaded installer to {}",
        installer_path.display()
    ));

    run_command(
        OsStr::new("msiexec.exe"),
        &[
            "/i",
            installer_path
                .to_str()
                .ok_or_else(|| "installer path is not valid UTF-8".to_owned())?,
            "/qn",
            "/norestart",
        ],
    )?;

    thread::sleep(Duration::from_secs(2));
    launch_installed_app()?;
    log_line("Legacy migration setup completed successfully.");
    Ok(())
}

fn fetch_latest_release() -> Result<ReleaseResponse, String> {
    let client = Client::builder()
        .timeout(Duration::from_secs(60))
        .build()
        .map_err(|e| format!("build http client: {e}"))?;
    let response = client
        .get(GITHUB_API_URL)
        .header("User-Agent", APP_NAME)
        .header("Accept", "application/vnd.github+json")
        .header("X-GitHub-Api-Version", "2022-11-28")
        .send()
        .map_err(|e| format!("fetch latest release: {e}"))?;
    let status = response.status();
    let body = response
        .text()
        .map_err(|e| format!("read latest release response: {e}"))?;
    if !status.is_success() {
        return Err(format!("latest release request failed: {status} body={body}"));
    }
    serde_json::from_str::<ReleaseResponse>(&body)
        .map_err(|e| format!("parse latest release json: {e}"))
}

fn download_file(url: &str, destination: &Path) -> Result<(), String> {
    let client = Client::builder()
        .timeout(Duration::from_secs(600))
        .build()
        .map_err(|e| format!("build download client: {e}"))?;
    let mut response = client
        .get(url)
        .header("User-Agent", APP_NAME)
        .send()
        .map_err(|e| format!("download installer: {e}"))?;
    let status = response.status();
    if !status.is_success() {
        let body = response
            .text()
            .unwrap_or_else(|_| "<unreadable body>".to_owned());
        return Err(format!("installer download failed: {status} body={body}"));
    }
    let mut file =
        fs::File::create(destination).map_err(|e| format!("create installer file: {e}"))?;
    response
        .copy_to(&mut file)
        .map_err(|e| format!("write installer file: {e}"))?;
    Ok(())
}

fn run_command<S: AsRef<OsStr>>(program: S, args: &[&str]) -> Result<(), String> {
    let program = program.as_ref();
    log_line(&format!(
        "Running command: {} {}",
        Path::new(program).display(),
        args.join(" ")
    ));
    let status = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(|e| format!("spawn command {}: {e}", Path::new(program).display()))?;
    if !status.success() {
        return Err(format!(
            "command failed: {} exit={status}",
            Path::new(program).display()
        ));
    }
    Ok(())
}

fn kill_process(image_name: &str) {
    let _ = Command::new("taskkill")
        .args(["/F", "/IM", image_name])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
}

fn launch_installed_app() -> Result<(), String> {
    let app_path = program_files_dir().join(APP_NAME).join(APP_EXE_NAME);
    if !app_path.exists() {
        return Err(format!(
            "installed application not found after migration: {}",
            app_path.display()
        ));
    }
    log_line(&format!("Launching installed app: {}", app_path.display()));
    Command::new(&app_path)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("launch installed app: {e}"))?;
    Ok(())
}

fn remove_path_with_retries(path: &Path) {
    if !path.exists() {
        return;
    }

    for _ in 0..10 {
        let result = if path.is_dir() {
            fs::remove_dir_all(path)
        } else {
            fs::remove_file(path)
        };
        if result.is_ok() || !path.exists() {
            log_line(&format!("Removed {}", path.display()));
            return;
        }
        thread::sleep(Duration::from_millis(500));
    }

    log_line(&format!(
        "Failed to fully remove {}; continuing.",
        path.display()
    ));
}

fn log_line(message: &str) {
    let line = format!("{message}\r\n");
    let _ = append_to_log(&line);
}

fn append_to_log(line: &str) -> Result<(), String> {
    let log_path = env::temp_dir().join("SFAIT_Remote_Assistant_migration.log");
    let mut file = fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .map_err(|e| format!("open migration log: {e}"))?;
    file.write_all(line.as_bytes())
        .map_err(|e| format!("write migration log: {e}"))
}

fn roaming_appdata_dir() -> PathBuf {
    env::var_os("APPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(|| env::temp_dir())
}

fn program_files_dir() -> PathBuf {
    env::var_os("ProgramW6432")
        .or_else(|| env::var_os("ProgramFiles"))
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(r"C:\Program Files"))
}

fn program_data_dir() -> PathBuf {
    env::var_os("ProgramData")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(r"C:\ProgramData"))
}

fn public_dir() -> PathBuf {
    env::var_os("PUBLIC")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(r"C:\Users\Public"))
}
