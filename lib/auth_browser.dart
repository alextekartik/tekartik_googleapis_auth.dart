// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library tekartk_googleapis_auth.auth_browser;

import 'dart:async';
import 'package:http/http.dart';
import 'package:http/browser_client.dart';

import 'package:googleapis_auth/auth.dart';
export 'package:googleapis_auth/auth_browser.dart' hide BrowserOAuth2Flow;
import 'package:googleapis_auth/src/auth_http_utils.dart';
import 'package:googleapis_auth/src/oauth2_flows/implicit.dart';
import 'package:googleapis_auth/src/http_client_base.dart';
import 'package:googleapis_auth/src/utils.dart';

import "dart:js" as js;

export 'package:googleapis_auth/auth.dart';


/// Will create and complete with a [BrowserOAuth2Flow] object.
///
/// This function will perform an implicit browser based oauth2 flow.
///
/// It will load Google's `gapi` library and initialize it. After initialization
/// it will complete with a [BrowserOAuth2Flow] object. The flow object can be
/// used to obtain `AccessCredentials` or an authenticated HTTP client.
///
/// If loading or initializing the `gapi` library results in an error, this
/// future will complete with an error.
///
/// If [baseClient] is not given, one will be automatically created. It will be
/// used for making authenticated HTTP requests. See [BrowserOAuth2Flow].
///
/// The [ClientId] can be obtained in the Google Cloud Console.
///
/// The user is responsible for closing the returned [BrowserOAuth2Flow] object.
/// Closing the returned [BrowserOAuth2Flow] will not close [baseClient]
/// if one was given.
Future<BrowserOAuth2Flow> createImplicitBrowserFlow(
    ClientId clientId, List<String> scopes, {Client baseClient}) {
  if (baseClient == null) {
    baseClient = new RefCountedClient(new BrowserClient(), initialRefCount: 1);
  } else {
    baseClient = new RefCountedClient(baseClient, initialRefCount: 2);
  }

  var flow = new ImplicitFlow(clientId.identifier, scopes);
  return flow.initialize().catchError((error, stack) {
    baseClient.close();
    return new Future.error(error, stack);
  }).then((_) => new BrowserOAuth2Flow._(flow, baseClient, clientId.identifier, scopes));
}

/// Used for obtaining oauth2 access credentials.
///
/// Warning:
///
/// The methods `obtainAccessCredentialsViaUserConsent` and
/// `clientViaUserConsent` try to open a popup window for the user authorization
/// dialog.
///
/// In order to prevent browsers from blocking the popup window, these
/// methods should only be called inside an event handler, since most
/// browsers do not block popup windows created in response to a user
/// interaction.
class BrowserOAuth2Flow {
  final ImplicitFlow _flow;
  final RefCountedClient _client;

  bool _wasClosed = false;

  // Tekartik added
  final String _clientId;
  final List<String> _scopes;

  /// The HTTP client passed in will be closed if `close` was called and all
  /// generated HTTP clients via [clientViaUserConsent] were closed.
  BrowserOAuth2Flow._(this._flow, this._client, this._clientId, this._scopes);

  /// Obtain oauth2 [AccessCredentials].
  ///
  /// If [immediate] is `true` there will be no user involvement. If the user
  /// is either not logged in or has not already granted the application access,
  /// a `UserConsentException` will be thrown.
  ///
  /// If [immediate] is `false` the user might be asked to login (if he is not
  /// already logged in) and might get asked to grant the application access
  /// (if the application hasn't been granted access before).
  ///
  /// The returned future will complete with `AccessCredentials` if the user
  /// has given the application access to it's data. Otherwise the future will
  /// complete with a `UserConsentException`.
  ///
  /// In case another error occurs the returned future will complete with an
  /// `Exception`.
  Future<AccessCredentials> obtainAccessCredentialsViaUserConsent({bool force, bool immediate: false, String userId}) {
    _ensureOpen();
    return _login(force: force, immediate: immediate, userId: userId);
  }

  /// Obtains [AccessCredentials] and returns an authenticated HTTP client.
  ///
  /// After obtaining access credentials, this function will return an HTTP
  /// [Client]. HTTP requests made on the returned client will get an
  /// additional `Authorization` header with the `AccessCredentials` obtained.
  ///
  /// In case the `AccessCredentials` expire, it will try to obtain new ones
  /// without user consent.
  ///
  /// See [obtainAccessCredentialsViaUserConsent] for how credentials will be
  /// obtained. Errors from [obtainAccessCredentialsViaUserConsent] will be let
  /// through to the returned `Future` of this function and to the returned
  /// HTTP client (in case of credential refreshes).
  ///
  /// The returned HTTP client will forward errors from lower levels via it's
  /// `Future<Response>` or it's `Response.read()` stream.
  ///
  /// The user is responsible for closing the returned HTTP client.
  Future<AutoRefreshingAuthClient> clientViaUserConsent({bool force, bool immediate: false, String userId}) {
    return obtainAccessCredentialsViaUserConsent(force: force, immediate: immediate, userId: userId).then(_clientFromCredentials);
  }

  /// Will close this [BrowserOAuth2Flow] object and the HTTP [Client] it is
  /// using.
  ///
  /// The clients obtained via [clientViaUserConsent] will continue to work.
  /// The client obtained via `newClient` of obtained [HybridFlowResult] objects
  /// will continue to work.
  ///
  /// After this flow object and all obtained clients were closed the underlying
  /// HTTP client will be closed as well.
  ///
  /// After calling this `close` method, calls to [clientViaUserConsent],
  /// [obtainAccessCredentialsViaUserConsent] and to `newClient` on returned
  /// [HybridFlowResult] objects will fail.
  void close() {
    _ensureOpen();
    _wasClosed = true;
    _client.close();
  }

  void _ensureOpen() {
    if (_wasClosed) {
      throw new StateError('BrowserOAuth2Flow has already been closed.');
    }
  }

  AutoRefreshingAuthClient _clientFromCredentials(AccessCredentials cred) {
    _ensureOpen();
    _client.acquire();
    return new _AutoRefreshingBrowserClient(_client, cred, _flow);
  }

  Future _login({bool hybrid, bool force, bool immediate, String userId}) {
    var completer = new Completer();

    // fix boolean
    hybrid = hybrid == true;
    force = force == true;
    immediate = immediate == true;

    var gapi = js.context['gapi']['auth'];

    var json = {
      'client_id': _clientId,
      'immediate': immediate,
      'approval_prompt': force ? 'force' : 'auto',
      'response_type': hybrid ? 'code token' : 'token',
      'scope': _scopes.join(' '),
      'access_type': hybrid ? 'offline' : 'online',
    };

    if (userId != null) {
      json['authuser'] = -1;
      json['user_id'] = userId;
    }

    gapi.callMethod('authorize', [new js.JsObject.jsify(json), (jsTokenObject) {
        var tokenType = jsTokenObject['token_type'];
        var token = jsTokenObject['access_token'];
        var expiresInRaw = jsTokenObject['expires_in'];
        var code = jsTokenObject['code'];
        //var state = jsTokenObject['state'];
        var error = jsTokenObject['error'];

        var expiresIn;
        if (expiresInRaw is String) {
          expiresIn = int.parse(expiresInRaw);
        }

        if (error != null) {
          completer.completeError(new UserConsentException('Failed to get user consent: $error.'));
        } else if (token == null || expiresIn is! int || tokenType != 'Bearer') {
          completer.completeError(new Exception('Failed to obtain user consent. Invalid server response.'));
        } else {
          var accessToken = new AccessToken('Bearer', token, expiryDate(expiresIn));
          var credentials = new AccessCredentials(accessToken, null, _scopes);

          if (hybrid) {
            if (code == null) {
              completer.completeError(new Exception('Expected to get auth code ' 'from server in hybrid flow, but did not.'));
            }
            completer.complete([credentials, code]);
          } else {
            completer.complete(credentials);
          }
        }
      }]);

    return completer.future;
  }
}

/// Represents the result of running a browser based hybrid flow.
///
/// The `credentials` field holds credentials which can be used on the client
/// side. The `newClient` function can be used to make a new authenticated HTTP
/// client using these credentials.
///
/// The `authorizationCode` can be sent to the server, which knows the
/// "client secret" and can exchange it with long-lived access credentials.
///
/// See the `obtainAccessCredentialsViaCodeExchange` function in the
/// `googleapis_auth.auth_io` library for more details on how to use the
/// authorization code.
class HybridFlowResult {
  final BrowserOAuth2Flow _flow;

  /// Access credentials for making authenticated HTTP requests.
  final AccessCredentials credentials;

  /// The authorization code received from the authorization endpoint.
  ///
  /// The auth code can be used to receive permanent access credentials.
  /// This requires a confidential client which can keep a secret.
  final String authorizationCode;

  HybridFlowResult(this._flow, this.credentials, this.authorizationCode);

  AutoRefreshingAuthClient newClient() {
    _flow._ensureOpen();
    return _flow._clientFromCredentials(credentials);
  }
}

class _AutoRefreshingBrowserClient extends AutoRefreshDelegatingClient {
  AccessCredentials credentials;
  ImplicitFlow _flow;
  Client _authClient;

  _AutoRefreshingBrowserClient(Client client, this.credentials, this._flow)
  : super(client) {
    _authClient = authenticatedClient(baseClient, credentials);
  }

  Future<StreamedResponse> send(BaseRequest request) {
    if (!credentials.accessToken.hasExpired) {
      return _authClient.send(request);
    } else {
      return _flow.login(immediate: true).then((newCredentials) {
        credentials = newCredentials;
        notifyAboutNewCredentials(credentials);
        _authClient = authenticatedClient(baseClient, credentials);
        return _authClient.send(request);
      });
    }
  }
}