import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'cloud.dart';
import 'providers.dart';

/// Gender values as stored; null means not set.
const genderLabels = {
  'male': 'Male',
  'female': 'Female',
  'other': 'Other',
  'private': 'Prefer not to say',
};

/// Where the profile photo comes from. It is kept in the app's own folder and never uploaded.
abstract interface class PhotoStore {
  /// Lets the user take or choose a photo; returns the path of the saved copy, or null.
  Future<String?> pick({required bool camera});
  Future<void> delete(String path);
}

class DevicePhotoStore implements PhotoStore {
  @override
  Future<String?> pick({required bool camera}) async {
    final x = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (x == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    // A new name each time, so the image cache never shows the old photo.
    final out = File(
      '${dir.path}/profile-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await File(x.path).copy(out.path);
    return out.path;
  }

  @override
  Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } on Object {
      // Already gone.
    }
  }
}

final photoStoreProvider = Provider<PhotoStore>((ref) => DevicePhotoStore());

/// Path of the photo the user chose on this phone, or null.
class ProfilePhotoNotifier extends Notifier<String?> {
  static const _key = 'profilePhoto';

  @override
  String? build() {
    final p = ref.watch(prefsProvider).getString(_key);
    return p != null && File(p).existsSync() ? p : null;
  }

  Future<bool> pick({required bool camera}) async {
    final path = await ref.read(photoStoreProvider).pick(camera: camera);
    if (path == null) return false;
    await remove();
    await ref.read(prefsProvider).setString(_key, path);
    state = path;
    return true;
  }

  Future<void> remove() async {
    final old = state ?? ref.read(prefsProvider).getString(_key);
    if (old != null) await ref.read(photoStoreProvider).delete(old);
    await ref.read(prefsProvider).remove(_key);
    state = null;
  }
}

final profilePhotoProvider = NotifierProvider<ProfilePhotoNotifier, String?>(
  ProfilePhotoNotifier.new,
);

/// What the app shows about the person. The saved name wins over the Google name; the phone
/// photo wins over the Google photo.
class Profile {
  const Profile({
    this.name,
    this.gender,
    this.email,
    this.photoPath,
    this.googleUrl,
  });
  final String? name, gender, email, photoPath, googleUrl;

  String get initial => (name ?? '').trim().isEmpty
      ? ''
      : name!.trim().characters.first.toUpperCase();
}

final profileProvider = Provider<Profile>((ref) {
  final s = ref.watch(snapshotProvider).value?.settings;
  final user = ref.watch(userProvider).value;
  final saved = s?.displayName;
  return Profile(
    name: saved != null && saved.isNotEmpty ? saved : user?.name,
    gender: s?.gender,
    email: user?.email,
    photoPath: ref.watch(profilePhotoProvider),
    googleUrl: user?.photoUrl,
  );
});

/// "Good evening, Tanim", or null when there is no name to greet.
String? greeting(DateTime now, String? name) {
  final first = (name ?? '').trim().split(RegExp(r'\s+')).first;
  if (first.isEmpty) return null;
  final hello = now.hour < 12
      ? 'Good morning'
      : now.hour < 17
      ? 'Good afternoon'
      : 'Good evening';
  return '$hello, $first';
}

/// The round profile picture: phone photo, else Google photo, else the first letter.
class Avatar extends StatelessWidget {
  const Avatar(this.profile, {super.key, this.size = 40});
  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ImageProvider? image = profile.photoPath != null
        ? FileImage(File(profile.photoPath!))
        : profile.googleUrl != null
        ? NetworkImage(profile.googleUrl!)
        : null;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.secondaryContainer,
      foregroundImage: image,
      // A failed download (offline) falls back to the letter below.
      onForegroundImageError: image == null ? null : (_, _) {},
      child: profile.initial.isEmpty
          ? Icon(
              Icons.person_outline,
              size: size * 0.55,
              color: scheme.onSecondaryContainer,
            )
          : Text(
              profile.initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700,
                color: scheme.onSecondaryContainer,
              ),
            ),
    );
  }
}
