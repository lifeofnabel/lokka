/// Aggregiertes Partner-Rating (denormalisiert in `merchantRatings/{id}`).
class MerchantRating {
  const MerchantRating({required this.avg, required this.count});

  final double avg;
  final int count;

  bool get hasRatings => count > 0;

  static const empty = MerchantRating(avg: 0, count: 0);
}
