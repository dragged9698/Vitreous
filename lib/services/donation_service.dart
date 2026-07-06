class DonationService {
  static const String donationUrl = 'https://liberapay.com/dragged9698';

  static bool get isEnabled {
    return const bool.fromEnvironment('ENABLE_DONATIONS', defaultValue: false);
  }
}
