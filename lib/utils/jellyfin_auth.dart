/// Builds values for the `Authorization` header expected by Jellyfin.
///
/// Jellyfin 12.0 no longer accepts the legacy `X-Emby-Token`,
/// `X-Emby-Authorization` and `api_key` methods. The
/// `Authorization: MediaBrowser ...` header is also understood by 10.x
/// servers, so the app uses only this form regardless of server version.
library;

const jellyfinAuthHeader = 'Authorization';

/// Header value for requests made with an access token.
String jellyfinAuthorization(String token) => _mediaBrowser({'Token': token});

/// Header value for `POST /Users/AuthenticateByName`, sent before the app
/// has a token. The server binds the issued token to [deviceId].
String jellyfinLoginAuthorization({
  required String deviceId,
  String client = 'JellyDawtyl',
  String device = 'Phone',
  String version = '1.0.0',
}) => _mediaBrowser({
  'Client': client,
  'Device': device,
  'DeviceId': deviceId,
  'Version': version,
});

/// Headers map with only the authorization header, for image loaders,
/// players and downloaders that take a plain map.
Map<String, String> jellyfinAuthHeaders(String token) => {
  jellyfinAuthHeader: jellyfinAuthorization(token),
};

// Values must be quoted and URL-encoded; the server decodes them.
String _mediaBrowser(Map<String, String> params) =>
    'MediaBrowser ${params.entries.map((e) => '${e.key}="${Uri.encodeComponent(e.value)}"').join(', ')}';
