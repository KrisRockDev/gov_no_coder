import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_content_aggregator/constants/app_constants.dart';

class PreferencesService {
  Future<String?> getLastDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.lastDirectoryKey);
  }

  Future<void> saveLastDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.lastDirectoryKey, path);
  }
}