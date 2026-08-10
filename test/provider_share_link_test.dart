import 'package:flutter_test/flutter_test.dart';
import 'package:ona_net/features/customer/data/provider_share_link.dart';

void main() {
  test('builds a public provider link', () {
    expect(
      providerShareLink('provider-123').toString(),
      'https://onanet-956af.web.app/providers/provider-123',
    );
  });

  test('supports a custom public app base URL', () {
    expect(
      providerShareLink(
        'provider 123',
        publicAppUrl: 'https://onanet.example/app',
      ).toString(),
      'https://onanet.example/app/providers/provider%20123',
    );
  });
}
