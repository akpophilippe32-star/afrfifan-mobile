class UserSubscription {
  final String creatorId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final bool isVerified;
  final String highestTier; // 'basic', 'premium', 'pro'
  final DateTime endDate;
  final bool isExpired;
  final int daysRemaining;
  final String displayStatus; // 'active', 'expiring_soon', 'expired'

  UserSubscription({
    required this.creatorId,
    required this.username,
    this.fullName,
    this.avatarUrl,
    required this.isVerified,
    required this.highestTier,
    required this.endDate,
    required this.isExpired,
    required this.daysRemaining,
    required this.displayStatus,
  });
}