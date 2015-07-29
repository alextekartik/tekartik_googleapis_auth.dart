library tekartik_google_auth.auth_utils;

import 'package:googleapis_auth/auth.dart';

Map clientIdToMap(ClientId clientId) {
  return {
    "id": clientId.identifier,
    "secret": clientId.secret
  };
}

ClientId clientIdFromMap(Map map) {
  return new ClientId(map["id"], map["secret"]);
}

Map accessCredentialsToMap(AccessCredentials credentials) {
  return {
    "token_type": credentials.accessToken.type,
    "token_data": credentials.accessToken.data,
    "token_expiry": credentials.accessToken.expiry.toString(),
    "refresh_token": credentials.refreshToken
  };
}

AccessCredentials accessCredentialsFromMap(Map map, List<String> scopes) {
  return new AccessCredentials(new AccessToken(
      map['token_type'],
      map['token_data'],
      DateTime.parse(map['token_expiry'])),
  map['refresh_token'],
  scopes);
}