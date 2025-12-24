// Pack Validator Script
// Validates UI packs before merge

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart validate_pack.dart <pack_id> [pack_id2...]');
    exit(1);
  }

  final rootDir = Directory.current.parent;
  var hasErrors = false;

  for (final packId in args) {
    print('\n─── Validating: $packId ───');

    final packDir = Directory(path.join(rootDir.path, 'packs', packId));

    if (!await packDir.exists()) {
      print('✗ Pack directory not found: $packId');
      hasErrors = true;
      continue;
    }

    try {
      await _validatePack(packDir, packId);
      print('✓ Pack $packId is valid');
    } catch (e) {
      print('✗ Validation failed: $e');
      hasErrors = true;
    }
  }

  exit(hasErrors ? 1 : 0);
}

Future<void> _validatePack(Directory packDir, String packId) async {
  // 1. Check manifest.json
  final manifestFile = File(path.join(packDir.path, 'manifest.json'));
  if (!await manifestFile.exists()) {
    throw 'Missing manifest.json';
  }

  final manifestContent = await manifestFile.readAsString();
  final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
  print('  ✓ manifest.json found');

  // 2. Validate required fields
  final requiredFields = ['name', 'description', 'author', 'license'];
  for (final field in requiredFields) {
    if (!manifest.containsKey(field) || manifest[field] == null) {
      throw 'Missing required field: $field';
    }
  }
  print('  ✓ Required fields present');

  // 3. Check versions directory
  final versionsDir = Directory(path.join(packDir.path, 'versions'));
  if (!await versionsDir.exists()) {
    throw 'Missing versions directory';
  }

  final versions =
      await versionsDir.list().where((e) => e.path.endsWith('.zip')).toList();

  if (versions.isEmpty) {
    throw 'No version files found';
  }
  print('  ✓ Found ${versions.length} version(s)');

  // 4. Validate version format
  for (final version in versions) {
    final versionName = path.basenameWithoutExtension(version.path);
    if (!RegExp(r'^\d+\.\d+\.\d+(-[\w.]+)?$').hasMatch(versionName)) {
      throw 'Invalid version format: $versionName (use semver)';
    }
  }
  print('  ✓ Version format valid');

  // 5. Check pack ID format
  if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(packId)) {
    throw 'Invalid pack ID format: $packId (use lowercase_with_underscores)';
  }
  print('  ✓ Pack ID format valid');

  // 6. Check previews (warning only)
  final previewsDir = Directory(path.join(packDir.path, 'previews'));
  if (!await previewsDir.exists()) {
    print('  ⚠ No previews directory (recommended)');
  } else {
    final previews = await previewsDir.list().toList();
    if (previews.isEmpty) {
      print('  ⚠ Previews directory is empty (recommended to add images)');
    } else {
      print('  ✓ Found ${previews.length} preview(s)');
    }
  }

  // 7. Validate license
  final license = manifest['license'] as String?;
  const validLicenses = [
    'MIT',
    'Apache-2.0',
    'BSD-2-Clause',
    'BSD-3-Clause',
    'GPL-2.0',
    'GPL-3.0',
    'ISC',
    'Unlicense',
  ];
  if (license != null && !validLicenses.contains(license)) {
    print(
        '  ⚠ Unknown license: $license (consider using: ${validLicenses.join(", ")})');
  } else {
    print('  ✓ License: $license');
  }

  // 8. Check screens array
  final screens = manifest['screens'] as List<dynamic>?;
  if (screens == null || screens.isEmpty) {
    throw 'No screens defined in manifest';
  }
  print('  ✓ ${screens.length} screen(s) defined');
}
