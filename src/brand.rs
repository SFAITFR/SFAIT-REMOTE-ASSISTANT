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
pub const WINDOWS_SETUP_ASSET: &str = "SFAIT_Remote_Assistant_setup.exe";

pub fn latest_release_url() -> String {
    format!("https://github.com/{}/releases/latest", GITHUB_REPO)
}

pub fn release_tag_url(version: &str) -> String {
    format!("https://github.com/{}/releases/tag/{}", GITHUB_REPO, version)
}
