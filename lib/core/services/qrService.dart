class QrService {
  const QrService();

  String buildUserWalletQrPayload({
    required String uid,
    required String customerCode,
  }) {
    return 'lokka://wallet/user/$uid/$customerCode';
  }

  String buildMerchantScannerPrefix({
    required String merchantId,
  }) {
    return 'lokka://merchant/$merchantId/scan';
  }

  String buildClaimPayload({
    required String type,
    required String id,
  }) {
    return '$type:$id';
  }
}
