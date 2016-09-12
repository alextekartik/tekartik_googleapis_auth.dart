// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:googleapis_auth/auth.dart';
import 'dart:io';
import 'package:googleapis/plus/v1.dart';
import 'package:path/path.dart';
import 'package:tekartik_googleapis_auth/auth_utils_io.dart';

// tekartik-noapi project - replace with your own
final List<String> scopes = ["https://www.googleapis.com/auth/plus.me"];//[drive.DriveApi.DriveScope]; //["email"];


main(List<String> args) async {

  ClientId clientId;
  String clientIdFilePath;
  try {
    clientIdFilePath = join(dirname(Platform.script.toFilePath()), clientIdFilename);
    clientId = getClientIdFromYamlFileSync(clientIdFilePath);
  } catch (e) {
    stderr.writeln('client id/secret expected in ${clientIdFilePath} in yaml format');
    exit(1);
  }

  var authClient = await getAuthClient(clientId, scopes, accessCredentialsFilePath: join(dirname(Platform.script.toFilePath()), accessCredentialsFilename));
  PlusApi plusApi = new PlusApi(authClient);
  Person person = await plusApi.people.get("me");
  print("person_id: ${person.id}");
  print("display_name: ${person.displayName}");
  if (person.emails != null) {
    person.emails.forEach((PersonEmails personEmail) {
      print('${personEmail.type}: ${personEmail.value}');
    });
  }

}
