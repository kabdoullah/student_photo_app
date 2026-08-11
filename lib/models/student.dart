import 'package:freezed_annotation/freezed_annotation.dart';

part 'student.freezed.dart';
part 'student.g.dart';

@freezed
abstract class Student with _$Student {
  const Student._();

  const factory Student({
    required String id,
    required String matricule,
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
  }) = _Student;

  factory Student.fromJson(Map<String, dynamic> json) =>
      _$StudentFromJson(json);

  factory Student.fromApiJson(
    Map<String, dynamic> json, {
    required String matricule,
  }) {
    String valueFor(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value != null) return value.toString();
      }
      return fallback;
    }

    return Student(
      id: valueFor(['id', 'student_id'], fallback: matricule),
      matricule: valueFor([
        'matricule',
        'registration_number',
      ], fallback: matricule),
      firstName: valueFor(['first_name', 'prenom', 'prénom']),
      lastName: valueFor(['last_name', 'nom']),
    );
  }

  String get fullName => '$firstName $lastName';
}
