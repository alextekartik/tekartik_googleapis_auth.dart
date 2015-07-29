import 'package:test/test.dart';
import 'package:tekartik_googleapis_auth/auth_utils.dart';

main() {
  group('auth_utils', () {
    test('access_credentials', () {
      Map map = {

        "token_type": "1",
        "token_data": "2",
        "token_expiry": new DateTime.now().toUtc().toString(),
        "refresh_token": "4"
      };
      expect(accessCredentialsToMap(accessCredentialsFromMap(map, ["some scopes"])), map);
    });

    test('client_id', () {
      Map map = {

        "id": "1",
        "secret": "2"
      };
      expect(clientIdToMap(clientIdFromMap(map)), map);
    });
  });
}