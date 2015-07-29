library tekartik_utils.google_auth_utils_io;

import 'dart:async';

import 'auth_utils.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis_auth/auth.dart' as auth;
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart';
import "package:http/http.dart" as http;
import 'dart:io';

String clientIdFilename = '.local_client_id.yaml';
String accessCredentialsFilename = '.local_access_credentials.yaml';

Map getMapFromYamlFileSync(String filename) {
  String fileContent;
  try {
    fileContent = new File(filename).readAsStringSync();
  } catch (e, st) {
    stderr.writeln('file not found in ${filename}');
    throw e;
  }

  try {
   return loadYaml(fileContent);
  } catch (e, st) {
    stderr.writeln('Expected content as yaml in ${filename}');
    throw e;
  }
}

void _writeMapToYamlFileSync(String filename, Map map) {
  StringBuffer sb = new StringBuffer();
  map.forEach((k, v) {
    sb.writeln("${k}: ${v}");
  });
  new File(filename).writeAsStringSync(sb.toString());

}

auth.ClientId getClientIdFromYamlFileSync(String filename) {
  return clientIdFromMap(getMapFromYamlFileSync(filename));
}

auth.AccessCredentials getAccessCredentialsFromYamlFileSync(String filename, List<String> scopes) {
  return accessCredentialsFromMap(getMapFromYamlFileSync(filename), scopes);
}

///
/// Mainly for testing
/// load the client id in .local_client_id file (that should not be in source control)
/// write temp credentials into .local_access_credentials file (that should not be in source control)
///
/// if [accessCredentialsFilePath] is not null, credentials are read/written for later use
Future<auth.AuthClient> getAuthClient(auth.ClientId clientId, List<String> scopes, {String accessCredentialsFilePath}) async {

  auth.AccessCredentials accessCredentials;
  try {
    if (accessCredentialsFilePath != null) {
      accessCredentials = getAccessCredentialsFromYamlFileSync(accessCredentialsFilePath, scopes);
    }
  } catch (e, st) {
    stderr.writeln('Credential file not found');
  }

  var client = new http.Client();

  if (accessCredentials == null) {
    try {
      accessCredentials = await auth.obtainAccessCredentialsViaUserConsent(clientId, scopes, client, _userPrompt);
    } catch (error) {
      if (error is auth.UserConsentException) {
        stderr.writeln("You did not grant access: $error");
      } else {
        stderr.writeln("An unknown error occured: $error");
      }
      client.close();
      throw error;
    }
    print(accessCredentials);
    if (accessCredentialsFilePath != null) {
      _writeMapToYamlFileSync(accessCredentialsFilePath, accessCredentialsToMap(accessCredentials));
    }
  }



  auth.AutoRefreshingAuthClient authClient = auth.autoRefreshingClient(clientId, accessCredentials, client);
  return authClient;
}

void _userPrompt(String url) {
  print("Please go to the following URL and grant access:");
  print("  => $url");
  print("");
}