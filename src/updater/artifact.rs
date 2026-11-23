use crate::{
    common::{display_version_from_release_id, release_id_from_update_url},
    hbbs_http::create_http_client_with_url_strict,
    update_metadata::{UpdateArtifactQuery, UpdateMetadataRequirements, VerifiedUpdateArtifact},
};
use hbb_common::{bail, ResultType};
use std::{
    io::Read,
    path::{Component, Path, PathBuf},
    sync::Mutex,
    time::Duration,
};

const UPDATE_SIDECAR_HTTP_REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
const UPDATE_METADATA_SIDECAR_MAX_BYTES: u64 = 1024 * 1024;

lazy_static::lazy_static! {
    static ref VERIFIED_UPDATE_ARTIFACT: Mutex<Option<VerifiedUpdateArtifact>> = Mutex::new(None);
}

pub(crate) fn current_update_platform() -> &'static str {
    #[cfg(target_os = "windows")]
    {
        "windows"
    }
    #[cfg(target_os = "macos")]
    {
        "macos"
    }
    #[cfg(not(any(target_os = "windows", target_os = "macos")))]
    {
        std::env::consts::OS
    }
}

pub(crate) fn current_update_arch() -> &'static str {
    #[cfg(all(target_os = "windows", not(feature = "flutter")))]
    {
        "x86"
    }
    #[cfg(not(all(target_os = "windows", not(feature = "flutter"))))]
    {
        std::env::consts::ARCH
    }
}

pub(crate) fn current_update_format(update_msi: bool) -> &'static str {
    #[cfg(any(
        not(target_os = "windows"),
        all(target_os = "windows", not(feature = "flutter"))
    ))]
    let _ = update_msi;
    #[cfg(all(target_os = "windows", feature = "flutter"))]
    {
        if update_msi {
            return "msi";
        }
        "exe"
    }
    #[cfg(all(target_os = "windows", not(feature = "flutter")))]
    {
        "exe"
    }
    #[cfg(target_os = "macos")]
    {
        "dmg"
    }
    #[cfg(not(any(target_os = "windows", target_os = "macos")))]
    {
        "unknown"
    }
}

pub fn current_update_artifact_query(update_msi: bool) -> UpdateArtifactQuery<'static> {
    UpdateArtifactQuery {
        platform: current_update_platform(),
        arch: current_update_arch(),
        format: current_update_format(update_msi),
    }
}

pub fn verified_update_artifact_for_release_page_url(
    release_page_url: &str,
    query: UpdateArtifactQuery<'_>,
) -> ResultType<VerifiedUpdateArtifact> {
    let artifact = verified_update_artifact_from_release_page_url(release_page_url, &query)?;
    *VERIFIED_UPDATE_ARTIFACT.lock().unwrap() = Some(artifact.clone());
    Ok(artifact)
}

pub fn verified_update_artifact_for_download_url(
    download_url: &str,
) -> ResultType<VerifiedUpdateArtifact> {
    VERIFIED_UPDATE_ARTIFACT
        .lock()
        .unwrap()
        .as_ref()
        .filter(|artifact| artifact.url == download_url)
        .cloned()
        .ok_or_else(|| hbb_common::anyhow::anyhow!("update artifact was not verified"))
}

// SFAIT: SFAIT releases are not signed with RustDesk's update key, so the signed
// `rustdesk-update.json` sidecar does not exist for them. The artifact is resolved
// from the SFAIT GitHub release instead, and its size and SHA-256 come from the
// GitHub API (asset `digest`), so the download is still checked before install.
pub(super) fn verified_update_artifact_from_release_page_url(
    update_url: &str,
    query: &UpdateArtifactQuery<'_>,
) -> ResultType<VerifiedUpdateArtifact> {
    let tag = update_url
        .trim_end_matches('/')
        .rsplit('/')
        .next()
        .unwrap_or_default();
    if tag.is_empty()
        || tag == "."
        || tag == ".."
        || tag.contains([' ', '/', '\\', '?', '#', '%'])
    {
        bail!("Update URL has no release tag: {}", update_url);
    }
    let version = tag.trim_start_matches('v').to_owned();
    let asset_name = sfait_update_asset_name(&version, query)?;
    let api_url = format!(
        "https://api.github.com/repos/{}/releases/tags/{}",
        crate::brand::GITHUB_REPO,
        tag
    );
    let client = create_http_client_with_url_strict(&api_url)?;
    let mut response = client
        .get(&api_url)
        .header("User-Agent", crate::brand::APP_NAME)
        .header("Accept", "application/vnd.github+json")
        .timeout(UPDATE_SIDECAR_HTTP_REQUEST_TIMEOUT)
        .send()?;
    if !response.status().is_success() {
        bail!("Failed to get release {}: {}", tag, response.status());
    }
    let body = read_limited_response_bytes(
        &mut response,
        UPDATE_METADATA_SIDECAR_MAX_BYTES,
        "GitHub release response",
    )?;
    let release: serde_json::Value = serde_json::from_slice(&body)?;
    let Some(asset) = release["assets"]
        .as_array()
        .and_then(|assets| assets.iter().find(|a| a["name"].as_str() == Some(&asset_name)))
    else {
        bail!("Release {} has no asset named {}", tag, asset_name);
    };
    let url = asset["browser_download_url"]
        .as_str()
        .unwrap_or_default()
        .to_owned();
    if get_update_download_file_from_url(&url).is_none() {
        bail!("Unexpected download URL for {}: {}", asset_name, url);
    }
    let Some(size) = asset["size"].as_u64().filter(|size| *size > 0) else {
        bail!("Release asset {} has no size", asset_name);
    };
    let sha256 = asset["digest"]
        .as_str()
        .and_then(|digest| digest.strip_prefix("sha256:"))
        .unwrap_or_default()
        .to_ascii_lowercase();
    if sha256.len() != 64 || !sha256.bytes().all(|b| b.is_ascii_hexdigit()) {
        bail!("Release asset {} has no SHA-256 digest", asset_name);
    }
    Ok(VerifiedUpdateArtifact {
        version,
        url,
        #[cfg(target_os = "macos")]
        file_name: asset_name,
        size,
        sha256,
    })
}

// SFAIT: asset names published by the SFAIT release workflows.
fn sfait_update_asset_name(version: &str, query: &UpdateArtifactQuery<'_>) -> ResultType<String> {
    match (query.platform, query.format) {
        ("windows", "msi") => Ok(crate::brand::WINDOWS_INSTALLER_ASSET.to_owned()),
        ("windows", "exe") => Ok(crate::brand::WINDOWS_PORTABLE_ASSET.to_owned()),
        ("macos", "dmg") => {
            let arch = if query.arch == "aarch64" { "arm64" } else { "x86_64" };
            Ok(format!(
                "{}-{}-{}.dmg",
                crate::brand::RELEASE_ASSET_PREFIX,
                version,
                arch
            ))
        }
        (platform, format) => bail!("No SFAIT update for {} ({})", platform, format),
    }
}

// Upstream verification of RustDesk-signed update metadata, kept for reference.
#[allow(dead_code)]
fn verified_rustdesk_update_artifact_from_release_page_url(
    update_url: &str,
    query: &UpdateArtifactQuery<'_>,
) -> ResultType<VerifiedUpdateArtifact> {
    let release_id = release_id_from_update_url(update_url)?;
    let display_version = display_version_from_release_id(&release_id)?;
    let expected_artifact_url_prefix =
        format!("https://github.com/rustdesk/rustdesk/releases/download/{release_id}/");
    let metadata_url = format!("{expected_artifact_url_prefix}rustdesk-update.json");
    let signature_url = format!("{metadata_url}.sig");
    let metadata_bytes = fetch_update_sidecar_bytes(&metadata_url)?;
    let signature_bytes = fetch_update_sidecar_bytes(&signature_url)?;
    let requirements = UpdateMetadataRequirements {
        expected_version: display_version.as_str(),
        expected_release_id: release_id.as_str(),
        expected_artifact_url_prefix: expected_artifact_url_prefix.as_str(),
        artifact: *query,
    };
    crate::update_metadata::verify_update_metadata(&metadata_bytes, &signature_bytes, requirements)
}

#[allow(dead_code)]
fn fetch_update_sidecar_bytes(url: &str) -> ResultType<Vec<u8>> {
    let client = create_http_client_with_url_strict(url)?;
    let mut response = client
        .get(url)
        .timeout(UPDATE_SIDECAR_HTTP_REQUEST_TIMEOUT)
        .send()?;
    if !response.status().is_success() {
        bail!(
            "Failed to download update metadata sidecar: {}",
            response.status()
        );
    }
    read_limited_response_bytes(
        &mut response,
        UPDATE_METADATA_SIDECAR_MAX_BYTES,
        "Update metadata sidecar",
    )
}

fn read_limited_response_bytes<R: Read>(
    reader: &mut R,
    limit: u64,
    what: &str,
) -> ResultType<Vec<u8>> {
    let mut limited_reader = reader.take(limit.saturating_add(1));
    let mut bytes = Vec::new();
    limited_reader.read_to_end(&mut bytes)?;
    if bytes.len() as u64 > limit {
        bail!("{what} exceeds maximum allowed size of {limit} bytes");
    }
    Ok(bytes)
}

pub fn get_update_download_file_from_url(url: &str) -> Option<PathBuf> {
    let parsed = url::Url::parse(url).ok()?;
    // Check the raw prefix before Url normalizes default ports.
    if !url.starts_with("https://github.com/")
        || parsed.scheme() != "https"
        || parsed.host_str() != Some("github.com")
        || !parsed.username().is_empty()
        || parsed.password().is_some()
        || parsed.port().is_some()
        || parsed.query().is_some()
        || parsed.fragment().is_some()
    {
        return None;
    }

    let mut segments = parsed.path_segments()?;
    let owner = segments.next()?;
    let repo = segments.next()?;
    let releases = segments.next()?;
    let download = segments.next()?;
    let tag = segments.next()?;
    let filename = segments.next()?;

    // SFAIT: only the SFAIT release repository is trusted for update downloads.
    let (expected_owner, expected_repo) = crate::brand::GITHUB_REPO
        .split_once('/')
        .unwrap_or_default();
    if !owner.eq_ignore_ascii_case(expected_owner)
        || !repo.eq_ignore_ascii_case(expected_repo)
        || releases != "releases"
        || download != "download"
        || tag.is_empty()
        || segments.next().is_some()
        || !is_plain_update_filename(filename)
    {
        return None;
    }

    Some(std::env::temp_dir().join(filename))
}

fn is_plain_update_filename(filename: &str) -> bool {
    if filename.is_empty()
        || filename.contains('/')
        || filename.contains('\\')
        || filename.contains(':')
    {
        return false;
    }

    let mut components = Path::new(filename).components();
    matches!(
        components.next(),
        Some(Component::Normal(name)) if name.to_str() == Some(filename)
    ) && components.next().is_none()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn update_download_file_accepts_expected_github_asset_urls() {
        let file = get_update_download_file_from_url(
            "https://github.com/SFAITFR/SFAIT-REMOTE-ASSISTANT/releases/download/v1.4.0/sfait-remote-assistant-1.4.0-x86_64.dmg",
        )
        .expect("valid GitHub release asset URL");

        assert_eq!(
            file.file_name().and_then(|name| name.to_str()),
            Some("sfait-remote-assistant-1.4.0-x86_64.dmg")
        );
    }

    #[test]
    fn update_download_file_rejects_untrusted_or_malformed_urls() {
        for url in [
            "http://github.com/rustdesk/rustdesk/releases/download/1/rustdesk.exe",
            "https://example.com/rustdesk.exe",
            "https://github.com/other/project/releases/download/1/rustdesk.exe",
            "https://github.com/rustdesk/rustdesk/releases/download/1/",
            "https://github.com/rustdesk/rustdesk/releases/download/1/nested/rustdesk.exe",
            "https://github.com/rustdesk/rustdesk/releases/download/1/C:rustdesk.exe",
            "https://user@github.com/rustdesk/rustdesk/releases/download/1/rustdesk.exe",
            "https://github.com:443/rustdesk/rustdesk/releases/download/1/rustdesk.exe",
            "https://github.com/rustdesk/rustdesk/releases/download/1/rustdesk.exe?download=1",
            "https://github.com/rustdesk/rustdesk/releases/download/1/rustdesk.exe#download",
            "not a url",
        ] {
            assert!(get_update_download_file_from_url(url).is_none(), "{url}");
        }
    }
}
