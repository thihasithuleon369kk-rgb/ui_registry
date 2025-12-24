import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Rebuilds index.json from GitHub Releases and the 'packs/' directory.
void main(List<String> args) async {
  final repo =
      args.isNotEmpty ? args.first : 'thihasithuleon369kk-rgb/ui_registry';
  final token = await _getToken();

  print('Rebuilding index for $repo...');

  final headers = {
    'Accept': 'application/vnd.github.v3+json',
    if (token != null) 'Authorization': 'token $token',
  };

  final filePacks = await _fetchFilePacks(repo, token, headers);
  print('Found ${filePacks.length} file-based pack(s).');

  final releasesUrl = Uri.parse('https://api.github.com/repos/$repo/releases');
  print('Fetching releases...');
  final response = await http.get(releasesUrl, headers: headers);

  if (response.statusCode != 200) {
    print('Failed to fetch releases: ${response.statusCode}');
    print(response.body);
    exit(1);
  }

  final releases = jsonDecode(response.body) as List;
  final packs = <Map<String, dynamic>>[];

  for (final release in releases) {
    final tagName = release['tag_name'] as String;
    print('Processing release $tagName...');

    final assets = release['assets'] as List;
    final bundleAsset = assets.firstWhere(
      (a) => a['name'] == 'bundle.zip',
      orElse: () => null,
    );

    if (bundleAsset == null) {
      print('  No bundle.zip found, skipping.');
      continue;
    }

    final downloadUrl = bundleAsset['browser_download_url'] as String;
    final previews = <String>[];

    // Find preview images in assets
    for (final asset in assets) {
      final name = asset['name'] as String;
      if (name != 'bundle.zip' && _isImage(name)) {
        previews.add(asset['browser_download_url'] as String);
      }
    }

    try {
      print('  Downloading bundle from $downloadUrl...');
      final bundleBytes = await http.readBytes(Uri.parse(downloadUrl));

      final archive = ZipDecoder().decodeBytes(bundleBytes);
      final manifestFile = archive.findFile('ui_manifest.json');

      if (manifestFile == null) {
        print('  No ui_manifest.json in bundle, skipping.');
        continue;
      }

      final manifestContent = utf8.decode(manifestFile.content as List<int>);
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

      final packId = manifest['id'] as String;
      final version = manifest['version'] as String;
      final publishedAt = release['published_at'] as String;

      packs.add({
        'id': packId,
        'name': manifest['name'] ?? packId,
        'description': manifest['description'] ?? '',
        'version': version,
        'author': manifest['author'] ?? 'Unknown',
        'authorUrl': manifest['authorUrl'],
        'license': manifest['license'] ?? 'MIT',
        'tags': manifest['tags'] ?? [],
        'downloads': 0,
        'downloadUrl': downloadUrl,
        'previews': previews,
        'screens': manifest['screens'] ?? [],
        'flutter': manifest['flutter'] ?? '>=3.0.0',
        'dependencies': manifest['dependencies'] ?? {},
        'createdAt': publishedAt,
        'updatedAt': publishedAt,
      });

      print('  ✓ Added $packId v$version');
    } catch (e) {
      print('  Error processing release $tagName: $e');
    }
  }

  // Combine both sources
  packs.addAll(filePacks);

  final latestPacks = <String, Map<String, dynamic>>{};
  for (final pack in packs) {
    final id = pack['id'] as String;
    if (!latestPacks.containsKey(id)) {
      latestPacks[id] = pack;
    } else {
      if (_compareVersions(pack['version'], latestPacks[id]!['version']) > 0) {
        latestPacks[id] = pack;
      }
    }
  }

  final indexData = {
    'version': '1.0',
    'updated': DateTime.now().toIso8601String(),
    'registry': 'https://github.com/$repo',
    'packs': latestPacks.values.toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String)),
  };

  final indexFile = File('registry/index.json');
  if (!await indexFile.parent.exists()) {
    await indexFile.parent.create(recursive: true);
  }

  final encoder = JsonEncoder.withIndent('  ');
  await indexFile.writeAsString(encoder.convert(indexData));

  print(
      '\n✓ Generated index.json with ${latestPacks.length} pack(s) at ${indexFile.path}');
}

Future<List<Map<String, dynamic>>> _fetchFilePacks(
    String repo, String? token, Map<String, String> headers) async {
  final result = <Map<String, dynamic>>[];
  try {
    final contentsUrl = 'https://api.github.com/repos/$repo/contents/packs';
    final response = await http.get(Uri.parse(contentsUrl), headers: headers);

    if (response.statusCode != 200) {
      if (response.statusCode == 404) return [];
      print('Failed to fetch packs directory: ${response.statusCode}');
      return [];
    }

    final packDirs = jsonDecode(response.body) as List;
    for (final dir in packDirs) {
      if (dir['type'] != 'dir') continue;
      final packId = dir['name'] as String;
      final versionsUrl = dir['url'] as String;

      final vResponse =
          await http.get(Uri.parse(versionsUrl), headers: headers);
      if (vResponse.statusCode != 200) continue;

      final versions = jsonDecode(vResponse.body) as List;
      for (final vDir in versions) {
        if (vDir['type'] != 'dir') continue;
        final version = vDir['name'] as String;
        final bundlePath = '${vDir['path']}/bundle.zip';

        // Check if bundle.zip exists
        final bundleUrl =
            'https://api.github.com/repos/$repo/contents/$bundlePath';
        final bResponse =
            await http.head(Uri.parse(bundleUrl), headers: headers);
        if (bResponse.statusCode != 200) continue;

        final downloadUrl = 'https://github.com/$repo/raw/main/$bundlePath';

        try {
          final bundleBytes = await http.readBytes(Uri.parse(downloadUrl));
          final archive = ZipDecoder().decodeBytes(bundleBytes);
          final manifestFile = archive.findFile('ui_manifest.json');
          if (manifestFile == null) continue;

          final manifestContent =
              utf8.decode(manifestFile.content as List<int>);
          final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

          result.add({
            'id': packId,
            'name': manifest['name'] ?? packId,
            'description': manifest['description'] ?? '',
            'version': version,
            'author': manifest['author'] ?? 'Unknown',
            'authorUrl': manifest['authorUrl'],
            'license': manifest['license'] ?? 'MIT',
            'tags': manifest['tags'] ?? [],
            'downloads': 0,
            'downloadUrl': downloadUrl,
            'previews': [],
            'screens': manifest['screens'] ?? [],
            'flutter': manifest['flutter'] ?? '>=3.0.0',
            'dependencies': manifest['dependencies'] ?? {},
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
          print('  ✓ Added file pack: $packId v$version');
        } catch (e) {
          print('  Error processing file pack $packId v$version: $e');
        }
      }
    }
  } catch (e) {
    print('Error in _fetchFilePacks: $e');
  }
  return result;
}

Future<String?> _getToken() async {
  var token = Platform.environment['GITHUB_TOKEN'];
  if (token != null) return token;
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null) {
    final file = File(path.join(home, '.ui_market_token'));
    if (await file.exists()) {
      return (await file.readAsString()).trim();
    }
  }
  return null;
}

bool _isImage(String name) {
  final ext = path.extension(name).toLowerCase();
  return ['.png', '.jpg', '.jpeg', '.webp', '.gif'].contains(ext);
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
