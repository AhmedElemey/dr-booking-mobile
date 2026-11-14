import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/failure.dart';
import '../domain/family_member.dart';

/// `/me/family`: the people the account owner books for (max 10).
class FamilyRepository {
  FamilyRepository(this._dio);

  static const maxMembers = 10;

  final Dio _dio;

  ApiResult<List<FamilyMember>> list() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/me/family');
    return [
      for (final m in response.data!)
        FamilyMember.fromJson(m as Map<String, dynamic>),
    ];
  });

  ApiResult<FamilyMember> add({
    required String fullName,
    required FamilyRelation relation,
    String? dateOfBirth,
    FamilyGender? gender,
  }) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/me/family',
      data: _body(fullName, relation, dateOfBirth, gender),
    );
    return FamilyMember.fromJson(response.data!);
  });

  ApiResult<FamilyMember> update(
    String id, {
    required String fullName,
    required FamilyRelation relation,
    String? dateOfBirth,
    FamilyGender? gender,
  }) => guardApi(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/me/family/$id',
      data: _body(fullName, relation, dateOfBirth, gender),
    );
    return FamilyMember.fromJson(response.data!);
  });

  ApiResult<void> delete(String id) => guardApi(() async {
    await _dio.delete<void>('/me/family/$id');
  });

  Map<String, dynamic> _body(
    String fullName,
    FamilyRelation relation,
    String? dateOfBirth,
    FamilyGender? gender,
  ) => {
    'fullName': fullName.trim(),
    'relation': relation.wire,
    'dateOfBirth': dateOfBirth,
    'gender': gender?.wire,
  };
}

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => FamilyRepository(ref.watch(dioProvider)),
);
