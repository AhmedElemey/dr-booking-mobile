import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/failure.dart';
import '../data/family_repository.dart';
import '../domain/family_member.dart';

/// The signed-in patient's family members; reload with `ref.invalidate`.
final familyMembersProvider = FutureProvider.autoDispose<List<FamilyMember>>(
  (ref) => ref.watch(familyRepositoryProvider).list().unwrap(),
);
