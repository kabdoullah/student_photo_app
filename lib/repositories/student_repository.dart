import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student.dart';
import '../viewmodels/auth_viewmodel.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(ref.watch(apiClientProvider));
});

class StudentRepository {
  final Dio _dio;
  StudentRepository(this._dio);

  Future<Student> getStudentByMatricule(String matricule) async {
    final response = await _dio.get<Map<String, dynamic>>('/eleve/$matricule');
    return Student.fromApiJson(response.data ?? const {}, matricule: matricule);
  }

  Future<void> uploadPhoto(String studentId, File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path),
    });
    await _dio.post('/eleve/$studentId/photo', data: formData);
  }
}
