import 'dart:typed_data';

import 'package:http/http.dart' as http;

abstract class HttpHelper {
  Future<bool> needUpdate(String url, {String? key});
  Future<Uint8List> getUint8List(String url, {Map<String, String>? headers});
}

class JmtHeepHepler extends HttpHelper {
  JmtHeepHepler();

  /// check whether redirectUrl update;
  @override
  Future<bool> needUpdate(String url, {String? key, Map<String, String>? authHeaders}) async {
    /// for debug ,so always request!
    return true;
  /*   
      final headers = <String, String>{};
      authHeaders?.forEach((key, value) {
        headers[key] = value;
      });

      final uri = Uri.parse(url);
      final req = http.Request('GET', uri);
      req.headers.addAll(headers);
      req.followRedirects = false;
      final httpResponse = await _httpClient.send(req);
      final location = httpResponse.headers['location'];
      return url == location; 
    */
  }

  final http.Client _httpClient = http.Client();

  @override
  Future<Uint8List> getUint8List(String url, {Map<String, String>? headers}) async {
    final req = http.Request('GET', Uri.parse(url));
    if (headers != null) {
      req.headers.addAll(headers);
    }
    final httpResponse = await _httpClient.send(req);

    return httpResponse.stream.toBytes();
  }
}
