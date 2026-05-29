class QrService {
  const QrService();

  String buildClaimPayload({
    required String type,
    required String id,
  }) {
    return '$type:$id';
  }
}
