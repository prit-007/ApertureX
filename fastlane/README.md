# F-Droid store metadata

This directory follows the Fastlane layout read by F-Droid from the upstream
repository:

```
fastlane/metadata/android/en-US/
├── title.txt
├── short_description.txt
├── full_description.txt
├── changelogs/<versionCode>.txt
└── images/
    ├── icon.png
    ├── featureGraphic.png
    └── phoneScreenshots/1.png, 2.png, ...
```

F-Droid uses Android **versionCodes**, not versionNames, for changelogs. This
project splits APKs per ABI, so each release uses `base × 10 + {1,2,3}` (for
example `0.2.4+4` produces `41.txt`, `42.txt`, and `43.txt`). The CI metadata
test (`tool/ci/test_fastlane_metadata.py`) enforces the filenames and text
limits.

Store screenshots still need to be captured from a device or emulator and
added under `images/phoneScreenshots/` before the fdroiddata submission.
