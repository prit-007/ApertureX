#!/usr/bin/env python3
"""Validate the upstream Fastlane metadata consumed by F-Droid.

F-Droid reads app-store metadata from ``fastlane/metadata/android/<locale>/``
when it builds from source. The changelog filenames must be Android
versionCodes (not versionNames), and the text fields have hard limits. Keeping
these checks in CI prevents a release tag from shipping metadata that F-Droid
silently ignores.
"""

from __future__ import annotations

import re
import struct
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
METADATA = REPO_ROOT / "fastlane" / "metadata" / "android" / "en-US"
PUBSPEC = REPO_ROOT / "app" / "pubspec.yaml"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != PNG_SIGNATURE:
        raise AssertionError(f"{path} is not a PNG")
    return struct.unpack(">II", data[16:24])


class FastlaneMetadataTest(unittest.TestCase):
    def test_required_text_files_exist(self) -> None:
        for name in ("title.txt", "short_description.txt", "full_description.txt"):
            path = METADATA / name
            self.assertTrue(path.is_file(), f"missing {path}")
            self.assertTrue(path.read_text(encoding="utf-8").strip(), f"empty {path}")

    def test_store_text_limits(self) -> None:
        short = (METADATA / "short_description.txt").read_text(encoding="utf-8").strip()
        full = (METADATA / "full_description.txt").read_text(encoding="utf-8").strip()
        title = (METADATA / "title.txt").read_text(encoding="utf-8").strip()

        self.assertLessEqual(len(short), 80, "short description exceeds 80 chars")
        self.assertFalse(short.endswith("."), "short description must not end with a dot")
        self.assertLessEqual(len(full), 4000, "full description exceeds 4000 chars")
        self.assertLessEqual(len(title), 50, "title exceeds 50 chars")

    def test_changelogs_match_android_version_codes(self) -> None:
        pubspec = PUBSPEC.read_text(encoding="utf-8")
        match = re.search(r"^version:\s*[0-9.]+\+(\d+)\s*$", pubspec, re.MULTILINE)
        self.assertIsNotNone(match, "app/pubspec.yaml has no versionCode build number")
        base = int(match.group(1))

        changelogs = METADATA / "changelogs"
        for offset in (1, 2, 3):
            path = changelogs / f"{base * 10 + offset}.txt"
            self.assertTrue(path.is_file(), f"missing per-ABI changelog {path.name}")
            text = path.read_text(encoding="utf-8")
            self.assertTrue(text.strip(), f"empty changelog {path.name}")
            self.assertLessEqual(len(text), 500, f"{path.name} exceeds 500 chars")

    def test_changelog_names_are_version_codes(self) -> None:
        for path in (METADATA / "changelogs").glob("*.txt"):
            self.assertTrue(
                path.stem.isdigit(),
                f"{path.name} must use an Android versionCode, not a versionName",
            )

    def test_icon_and_feature_graphic(self) -> None:
        self.assertEqual(png_size(METADATA / "images" / "icon.png"), (512, 512))
        self.assertEqual(
            png_size(METADATA / "images" / "featureGraphic.png"), (1024, 500)
        )


if __name__ == "__main__":
    unittest.main()
