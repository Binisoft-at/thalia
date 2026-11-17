#!/usr/bin/env python3
"""Thalia's own read-only probe (asc-probe.yml): which App Store Connect requests answer, and which
fail with HTTP 500. Xcode's iOS export asks for the app with its App Store versions included and
got "An unexpected error occurred" (1.6.0, Nov 2026). Uses the handbook's scripts/ci/asc.py."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "ci"))
import asc  # noqa: E402

BUNDLE = os.environ.get("BUNDLE_ID", "at.binisoft.thalia")


def probe(label, path, params=None):
    try:
        data = asc.request("GET", path, params, retries=1)
        items = data.get("data", [])
        count = len(items) if isinstance(items, list) else 1
        print(f"OK    {label}: {count} item(s)")
        return data
    except Exception as error:  # noqa: BLE001 – a probe reports every failure
        text = str(error).replace("\n", " ")
        print(f"FAIL  {label}: {text[:300]}")
        return None


def main():
    if not asc.has_key():
        sys.exit("ASC key secrets missing")
    apps = probe("apps by bundle id", "/apps", {"filter[bundleId]": BUNDLE})
    probe("apps + appStoreVersions (Xcode's export request)", "/apps", {
        "fields[appStoreVersions]": "platform,versionString",
        "fields[apps]": "name,bundleId,appStoreVersions",
        "filter[bundleId]": BUNDLE,
        "include": "appStoreVersions",
        "limit": "100",
        "limit[appStoreVersions]": "10",
        "sort": "name",
    })
    if not apps or not apps.get("data"):
        return
    app_id = apps["data"][0]["id"]
    versions = probe("appStoreVersions of the app", f"/apps/{app_id}/appStoreVersions", {"limit": "50"})
    if versions:
        for version in versions.get("data", []):
            attrs = version.get("attributes", {})
            print(f"      version {attrs.get('platform')} {attrs.get('versionString')} · {attrs.get('appStoreState') or attrs.get('appVersionState')}")
    for platform in ["IOS", "MAC_OS"]:
        probe(f"appStoreVersions filter platform={platform}", f"/apps/{app_id}/appStoreVersions",
              {"filter[platform]": platform, "limit": "10"})
    probe("preReleaseVersions of the app", "/preReleaseVersions", {"filter[app]": app_id, "limit": "20"})
    probe("builds of the app", "/builds", {"filter[app]": app_id, "limit": "5"})


if __name__ == "__main__":
    main()
