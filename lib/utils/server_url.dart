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
