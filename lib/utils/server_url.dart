/// Returns the canonical form of a Jellyfin server address.
///
/// An address typed without a scheme gets `https://`, which is what the login
/// request has always used for such input, so an address that worked at login
/// keeps pointing to the same server. Surrounding whitespace and trailing
/// slashes are removed so that `"$baseUrl/Users/..."` never produces `//`.
/// The function is idempotent and is applied both before saving the address
/// and when reading an address saved by an older version of the app.
String normalizeServerUrl(String input) {
  var value = input.trim();
  if (value.isEmpty) return value;
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
    value = 'https://$value';
  }
  return value.replaceFirst(RegExp(r'/+$'), '');
}

/// Whether [address] uses plain `http://` to a host outside the local
/// network, so the password and the access token would cross the internet
/// unencrypted. Addresses without a scheme become `https://` and are safe.
bool isInsecurePublicAddress(String address) {
  final value = address.trim();
  if (!RegExp(r'^http://', caseSensitive: false).hasMatch(value)) {
    return false;
  }
  final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  return !isLocalNetworkHost(host);
}

/// Loopback, private IPv4/IPv6 ranges, link-local, `.local`/`.lan` names and
/// single-label host names (resolved by the local DNS).
bool isLocalNetworkHost(String host) {
  final h = host.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
  if (h == 'localhost' ||
      h.endsWith('.local') ||
      h.endsWith('.lan') ||
      h.endsWith('.home.arpa') ||
      h.endsWith('.internal')) {
    return true;
  }
  final ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
  final m = ipv4.firstMatch(h);
  if (m != null) {
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    return a == 10 ||
        a == 127 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 169 && b == 254) ||
        (a == 100 && b >= 64 && b <= 127); // CGNAT, e.g. Tailscale
  }
  if (h.contains(':')) {
    return h == '::1' ||
        h.startsWith('fc') ||
        h.startsWith('fd') ||
        h.startsWith('fe80');
  }
  return !h.contains('.');
}
