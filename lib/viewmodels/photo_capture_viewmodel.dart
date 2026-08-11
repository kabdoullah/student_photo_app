import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/student.dart';
import '../repositories/student_repository.dart';

part 'photo_capture_viewmodel.g.dart';

@Riverpod(keepAlive: true)
class PhotoCaptureViewModel extends _$PhotoCaptureViewModel {
  @override
  FutureOr<Student?> build() => null;

  Future<void> searchStudent(String matricule) async {
    final clean = matricule.trim();
    if (clean.isEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await ref
          .read(studentRepositoryProvider)
          .getStudentByMatricule(clean);
    });
  }

  void selectStudent(Student student) {
    state = AsyncData(student);
  }

  void clearStudent() {
    state = const AsyncData(null);
  }

  Future<bool> uploadPhoto(File imageFile) async {
    final student = state.value;
    if (student == null) return false;

    state = const AsyncLoading<Student?>();
    final result = await AsyncValue.guard(() async {
      await ref
          .read(studentRepositoryProvider)
          .uploadPhoto(student.matricule, imageFile);
      return student;
    });

    state = result;
    return !result.hasError;
  }
}
