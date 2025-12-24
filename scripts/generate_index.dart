// Registry Index Generator
// Scans /packs directory and generates registry/index.json

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

void main() async {
  final rootDir = Directory.current.parent;
  final packsDir = Directory(path.join(rootDir.path, 'packs'));
  final indexFile = File(path.join(rootDir.path, 'registry', 'index.json'));

  if (!await packsDir.exists()) {
    print('No packs directory found');
    exit(1);
  }

  final packs = <Map<String, dynamic>>[];

  await for (final packDir in packsDir.list()) {
    if (packDir is! Directory) continue;

    final packId = path.basename(packDir.path);
    final manifestFile = File(path.join(packDir.path, 'manifest.json'));

    if (!await manifestFile.exists()) {
      print('Warning: No manifest.json for $packId, skipping');
      continue;
    }

    try {
      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

      // Get latest version
      final versionsDir = Directory(path.join(packDir.path, 'versions'));
      String? latestVersion;
      String? downloadUrl;

      if (await versionsDir.exists()) {
        final versions = await versionsDir
            .list()
            .where((e) => e.path.endsWith('.zip'))
            .map((e) => path.basenameWithoutExtension(e.path))
            .toList();

        if (versions.isNotEmpty) {
          versions.sort(_compareVersions);
          latestVersion = versions.last;
          downloadUrl = _getDownloadUrl(packId, latestVersion);
        }
      }

      // Get preview images
      final previewsDir = Directory(path.join(packDir.path, 'previews'));
      final previews = <String>[];

      if (await previewsDir.exists()) {
        await for (final preview in previewsDir.list()) {
          if (preview is File) {
            final ext = path.extension(preview.path).toLowerCase();
            if (['.png', '.jpg', '.jpeg', '.webp', '.gif'].contains(ext)) {
              previews.add(_getPreviewUrl(packId, path.basename(preview.path)));
            }
          }
        }
        previews.sort();
      }

      // Get timestamps from git or file
      final createdAt =
          manifest['createdAt'] ?? DateTime.now().toIso8601String();
      final updatedAt = DateTime.now().toIso8601String();

      packs.add({
        'id': packId,
        'name': manifest['name'] ?? packId,
        'description': manifest['description'] ?? '',
        'version': latestVersion ?? manifest['version'] ?? '1.0.0',
        'author': manifest['author'] ?? 'Unknown',
        'authorUrl': manifest['authorUrl'],
        'license': manifest['license'] ?? 'MIT',
        'tags': manifest['tags'] ?? [],
        'downloads': manifest['downloads'] ?? 0,
        'downloadUrl': downloadUrl ?? '',
        'previews': previews,
        'screens': manifest['screens'] ?? [],
        'flutter': manifest['flutter'] ?? '>=3.0.0',
        'dependencies': manifest['dependencies'] ?? {},
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });

      print('✓ Processed $packId (v$latestVersion)');
    } catch (e) {
      print('Error processing $packId: $e');
    }
  }

  // Sort by name
  packs.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

  final index = {
    'version': '1.0',
    'updated': DateTime.now().toIso8601String(),
    'registry': _getRegistryUrl(),
    'packs': packs,
  };

  final encoder = JsonEncoder.withIndent('  ');
  await indexFile.parent.create(recursive: true);
  await indexFile.writeAsString(encoder.convert(index));

  print('\n✓ Generated index.json with ${packs.length} pack(s)');
}

int _compareVersions(String a, String b) {
  final aParts = a.split('.').map(int.tryParse).toList();
  final bParts = b.split('.').map(int.tryParse).toList();

  for (var i = 0; i < 3; i++) {
    final aNum = i < aParts.length ? (aParts[i] ?? 0) : 0;
    final bNum = i < bParts.length ? (bParts[i] ?? 0) : 0;
    if (aNum != bNum) return aNum.compareTo(bNum);
  }
  return 0;
}

String _getRegistryUrl() {
  // Try to get from environment or default
  return Platform.environment['REGISTRY_URL'] ??
      'https://github.com/your-org/flutter-ui-registry';
}

String _getDownloadUrl(String packId, String version) {
  final registry = _getRegistryUrl();
  return '$registry/releases/download/$packId-$version/bundle.zip';
}

String _getPreviewUrl(String packId, String filename) {
  final registry = _getRegistryUrl();
  // Convert github.com URL to raw URL
  final rawUrl = registry.replaceFirst(
    'github.com',
    'raw.githubusercontent.com',
  );
  return '$rawUrl/main/packs/$packId/previews/$filename';
}
