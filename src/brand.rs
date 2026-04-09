pub const APP_NAME: &str = "SFAIT Remote Assistant";
pub const BUNDLE_ORG: &str = "fr.sfait";
pub const BUNDLE_IDENTIFIER: &str = "fr.sfait.remoteassistant";
pub const URI_SCHEME: &str = "sfaitremoteassistant";

pub const SERVER_HOST: &str = "remote-assistant.sfait.fr";
pub const RELAY_HOST: &str = "remote-assistant.sfait.fr";
pub const API_SERVER: &str = "https://remote-assistant.sfait.fr";
pub const SERVER_KEY: &str = "CIib1hejuz7TSWXa19yUBcCiTfYqaY14aw5r3BXA89w=";

pub const RELEASE_ASSET_PREFIX: &str = "sfait-remote-assistant";
pub const GITHUB_REPO: &str = "SFAITFR/SFAIT-REMOTE-ASSISTANT";
pub const WINDOWS_INSTALLER_ASSET: &str = "SFAIT_Remote_Assistant_installer.msi";
pub const WINDOWS_PORTABLE_ASSET: &str = "SFAIT_Remote_Assistant_portable.exe";
pub const UPDATE_API_URL_ENV: &str = "SFAIT_UPDATE_API_URL";
pub const UPDATE_BASE_URL_ENV: &str = "SFAIT_UPDATE_BASE_URL";

fn release_base_url() -> String {
    if let Ok(base_url) = std::env::var(UPDATE_BASE_URL_ENV) {
        let trimmed = base_url.trim().trim_end_matches('/');
        if !trimmed.is_empty() {
            return trimmed.to_owned();
        }
    }
    format!("https://github.com/{}/releases", GITHUB_REPO)
}

pub fn latest_release_api_url() -> String {
    if let Ok(api_url) = std::env::var(UPDATE_API_URL_ENV) {
        let trimmed = api_url.trim();
        if !trimmed.is_empty() {
            return trimmed.to_owned();
        }
    }
    format!("https://api.github.com/repos/{}/releases/latest", GITHUB_REPO)
}

pub fn latest_release_url() -> String {
    format!("{}/latest", release_base_url())
}

pub fn release_tag_url(version: &str) -> String {
    format!("{}/tag/{}", release_base_url(), version)
}

pub fn release_download_url(version: &str, asset_name: &str) -> String {
    format!("{}/download/{}/{}", release_base_url(), version, asset_name)
}

pub fn windows_release_asset(use_installer: bool) -> &'static str {
    if use_installer {
        WINDOWS_INSTALLER_ASSET
    } else {
        WINDOWS_PORTABLE_ASSET
    }
}
