const String _defaultPublicAppUrl = 'https://onanet-956af.web.app';

/// Builds the public HTTPS link sent when a customer shares a provider.
///
/// The base can be replaced at build time when OnaNet moves to a custom domain:
/// `--dart-define=ONA_NET_PUBLIC_APP_URL=https://example.com`
Uri providerShareLink(
  String providerId, {
  String publicAppUrl = const String.fromEnvironment(
    'ONA_NET_PUBLIC_APP_URL',
    defaultValue: _defaultPublicAppUrl,
  ),
}) {
  final base = Uri.parse(publicAppUrl.trim());
  final normalizedBase = base.path.endsWith('/')
      ? base
      : base.replace(path: '${base.path}/');
  return normalizedBase.resolve(
    'providers/${Uri.encodeComponent(providerId.trim())}',
  );
}
