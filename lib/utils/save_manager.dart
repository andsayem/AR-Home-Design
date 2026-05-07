import 'dart:convert';
import 'package:homedesign/models/project_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaveManager {
  static const String _key = 'saved_projects';

  static Future<void> saveProject(ProjectModel project) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_key) ?? [];
    
    // Check if updating existing
    final idx = saved.indexWhere((s) => ProjectModel.fromJson(jsonDecode(s)).id == project.id);
    if (idx != -1) {
      saved[idx] = jsonEncode(project.toJson());
    } else {
      saved.add(jsonEncode(project.toJson()));
    }
    
    await prefs.setStringList(_key, saved);
  }

  static Future<List<ProjectModel>> getAllProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_key) ?? [];
    return saved.map((s) => ProjectModel.fromJson(jsonDecode(s))).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> deleteProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_key) ?? [];
    saved.removeWhere((s) => ProjectModel.fromJson(jsonDecode(s)).id == id);
    await prefs.setStringList(_key, saved);
  }
}
