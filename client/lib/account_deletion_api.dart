abstract interface class AccountDeletionApi {
  Future<Map<String, dynamic>> accountDeletionStatus();
  Future<Map<String, dynamic>> requestAccountDeletion({String? password});
}

abstract interface class AgeAwareAccountApi {
  Future<void> createAccountWithAge(
    String name,
    String email,
    String password, {
    required bool ageAcknowledged,
  });
}
