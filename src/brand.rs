// SFAIT ships two editions built from the same code:
// - Client (default): "SFAIT Remote Assistant", incoming connections only (ID + password).
// - Technician (`--features technician`): "SFAIT Remote Assistant Technician", the full app.
// Each edition has its own name, bundle identifier, URI scheme and release assets, so both
// can be installed side by side and each one updates to its own files.
pub const IS_TECHNICIAN: bool = cfg!(feature = "technician");

pub const CLIENT_APP_NAME: &str = "SFAIT Remote Assistant";
pub const CLIENT_BUNDLE_IDENTIFIER: &str = "fr.sfait.remoteassistant";

pub const APP_NAME: &str = if IS_TECHNICIAN {
    "SFAIT Remote Assistant Technician"
} else {
    CLIENT_APP_NAME
};
pub const BUNDLE_ORG: &str = "fr.sfait";
pub const BUNDLE_IDENTIFIER: &str = if IS_TECHNICIAN {
    "fr.sfait.remoteassistant.technician"
} else {
    CLIENT_BUNDLE_IDENTIFIER
};
pub const URI_SCHEME: &str = if IS_TECHNICIAN {
    "sfaitremoteassistanttechnician"
} else {
    "sfaitremoteassistant"
};

pub const SERVER_HOST: &str = "remote-assistant.sfait.fr";
pub const RELAY_HOST: &str = "remote-assistant.sfait.fr";
pub const API_SERVER: &str = "https://remote-assistant.sfait.fr";
pub const SERVER_KEY: &str = "CIib1hejuz7TSWXa19yUBcCiTfYqaY14aw5r3BXA89w=";

pub const RELEASE_ASSET_PREFIX: &str = if IS_TECHNICIAN {
    "sfait-remote-assistant-technician"
} else {
    "sfait-remote-assistant"
};
pub const GITHUB_REPO: &str = "SFAITFR/SFAIT-REMOTE-ASSISTANT";
pub const WINDOWS_INSTALLER_ASSET: &str = if IS_TECHNICIAN {
    "SFAIT_Remote_Assistant_Technician_installer.msi"
} else {
    "SFAIT_Remote_Assistant_installer.msi"
};
pub const WINDOWS_PORTABLE_ASSET: &str = if IS_TECHNICIAN {
    "SFAIT_Remote_Assistant_Technician_portable.exe"
} else {
    "SFAIT_Remote_Assistant_portable.exe"
};
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
