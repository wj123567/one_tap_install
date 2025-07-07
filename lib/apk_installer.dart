import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class ApkInstaller {
  final String appApiUrl = 'https://api.github.com/repos/wj123567/one_tap_install/releases/latest';
  final String ytApiUrl = 'https://api.github.com/repos/wj123567/update_apk/releases/latest';

  /// Step 1: Fetch the latest APK URL from GitHub release
  Future<String?> getLatestApkUrl(bool isYt) async {
    try {
      final response = await Dio().get(isYt?ytApiUrl:appApiUrl);
      final assets = response.data['assets'] as List<dynamic>;

      final apkAsset = assets.firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
        orElse: () => null,
      );

      return apkAsset != null ? apkAsset['browser_download_url'] : null;
    } catch (e) {
      print("Error fetching latest release: $e");
      return null;
    }
  }

  /// Step 2: Download the APK file
  Future<String?> downloadApk(String apkUrl) async {
    try {

      final hasPermission = await requestStoragePermission();

      if (hasPermission) {
      final dir = Directory('/storage/emulated/0/Download');
      final filePath = '${dir.path}/update.apk';

      await Dio().download(
        apkUrl,
        filePath,
      );

      return filePath;
      }else{
        return null;
      }
    } catch (e) {
      print("Download error: $e");
      return null;
    }
  }

  /// Step 3: Prompt install using system installer
  Future<void> promptInstallApk(String apkPath) async {
    final result = await OpenFile.open(apkPath);
    print("OpenFile result: $result");

    Future.delayed(Duration(seconds: 10), () async {
      final file = File(apkPath);
      if (await file.exists()) {
        await file.delete();
        print("APK deleted after install.");
      }
    });
  }

  /// One public method to call from UI
  Future<void> updateApp(BuildContext context, bool isYt) async {
    loadingOverlay(context);

    final apkUrl = await getLatestApkUrl(isYt);
    if (apkUrl == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No APK found in latest release.")));
      return;
    }

    String? apkPath = await downloadApk(apkUrl);

    Navigator.pop(context);

    if (apkPath != null) {
      await promptInstallApk(apkPath);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to download APK.")));
    }
  }
}

Future<bool> requestStoragePermission() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    status = await Permission.manageExternalStorage.request();
  }
  return status.isGranted;
}

Future loadingOverlay(BuildContext context) {
  return showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      );
    },
  );
}

