import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ona_net/core/utils/provider_filters.dart';
import 'package:ona_net/core/widgets/provider_badges.dart';

void main() {
  test('humanizes backend values before displaying them', () {
    expect(humanizeBackendValue('pending_review'), 'Pending Review');
    expect(humanizeBackendValue('local-provider'), 'Local Provider');
    expect(humanizeBackendValue('no_contract'), 'No Contract');
  });

  test('provider approval alone does not imply document verification', () {
    expect(isVerifiedProvider({'status': 'approved'}), isFalse);
    expect(isVerifiedProvider({'is_verified': true}), isTrue);
    expect(
      isVerifiedProvider({'document_verification_status': 'verified'}),
      isTrue,
    );
  });

  testWidgets('shows verification and plan badges independently', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProviderBadges(
            provider: {'is_verified': true, 'planTier': 'growth'},
          ),
        ),
      ),
    );

    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Growth'), findsOneWidget);
    expect(find.text('Pro'), findsNothing);
  });

  testWidgets('shows Pro without claiming the provider is verified', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProviderBadges(
            provider: {'is_verified': false, 'planTier': 'pro'},
          ),
        ),
      ),
    );

    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
  });
}
