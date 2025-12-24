# Flutter UI Marketplace Registry

The official registry for Flutter UI Marketplace packs.

## Structure

```
flutter-ui-registry/
├── .github/
│   └── workflows/
│       ├── validate_pr.yml    # Validates pack PRs
│       └── rebuild_index.yml  # Rebuilds index.json
├── registry/
│   └── index.json             # Master pack list
├── packs/
│   └── {pack_id}/
│       ├── manifest.json
│       ├── versions/
│       │   └── {version}.zip
│       └── previews/
│           └── preview_*.png
└── scripts/
    ├── generate_index.dart
    └── validate_pack.dart
```

## Adding a Pack

### Option 1: CLI Upload (Recommended)

```bash
# Install CLI
dart pub global activate ui_market

# Upload your pack
export GITHUB_TOKEN=ghp_yourtoken
ui_market upload ./my_pack
```

### Option 2: Pull Request

1. Fork this repository
2. Create your pack directory under `packs/your_pack_id/`
3. Add required files:
   - `manifest.json` - Pack metadata
   - `versions/1.0.0.zip` - Bundled pack
   - `previews/preview_1.png` - Preview images
4. Submit a pull request

### manifest.json

```json
{
  "name": "My UI Pack",
  "description": "Description",
  "author": "Author Name",
  "authorUrl": "https://github.com/author",
  "license": "MIT",
  "flutter": ">=3.10.0 <4.0.0",
  "screens": [
    {
      "name": "ScreenName",
      "route": "/route",
      "file": "screens/file.dart"
    }
  ],
  "dependencies": {},
  "tags": ["tag1", "tag2"]
}
```

## Pack Requirements

- ✅ Uses `StatelessWidget` only
- ✅ No state management libraries
- ✅ No networking code
- ✅ Passes `flutter analyze`
- ✅ Passes `dart format`
- ✅ Has at least one preview image
- ✅ Uses semver versioning

## CI/CD

- **validate_pr.yml** - Runs on PR, validates pack structure
- **rebuild_index.yml** - Runs on merge, rebuilds `index.json`

## Self-Hosting

Fork this repo to run your own registry:

1. Fork to your organization
2. Update GitHub Actions if needed
3. Point users to your fork's URL

## License

Registry infrastructure: MIT
Individual packs: See each pack's license
