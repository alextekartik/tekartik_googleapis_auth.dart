import 'package:tekartik_googleapis_auth/auth_browser.dart';
import 'package:googleapis/plus/v1.dart';
import 'dart:html';
import 'dart:async';

// tekartik-noapi project - replace with your own
final ClientId clientId = new ClientId("673610294238-qvk8j295q46sb752nj20oapdjsmrmgde.apps.googleusercontent.com", null);
final List<String> scopes = ["email"];

// deployed to
// gsdeploy.dart  build/deploy/example/tekartik_googleapis_auth gs://gstest.tekartik.com/tekartik_googleapis_auth_test
Element statusElement;
Element errorElement;
ButtonElement logInButton;
ButtonElement logOutButton;
ButtonElement logInHybridButton;
BrowserOAuth2Flow _flow;

set status(String msg) {
  statusElement.innerHtml = msg;
  print(msg);
  error = '';
}

set error(String msg) {
  errorElement.innerHtml = msg;
  if (msg != null && msg.length > 0) {
    print('ERR ${msg}');
  }
}

void setErrorStatus(String msg, e, st) {
  error = "msg: $msg\nerr: $e\n st: $st";
}

Future clientViaUserConsent(BrowserOAuth2Flow flow, {bool immediate, String userId}) {
// Try am immediate sign-in first
  return flow.clientViaUserConsent(immediate: immediate, userId: userId).then((AutoRefreshingAuthClient client) {
    onLoggedIn(client);
  }).catchError((e, st) {
    setErrorStatus("clientViaUserConsent", e, st);
  });
}

_saveUserId(String userId) {
  window.localStorage['tekartik_test_user_id'] = userId;
}

String _loadUserId() {
  return window.localStorage['tekartik_test_user_id'];
}

onLoggedIn(AutoRefreshingAuthClient authClient) {
  status = "accessToken: ${authClient.credentials.accessToken}";
  PlusApi plusApi = new PlusApi(authClient);
  plusApi.people.get("me").then((Person person) {
    _saveUserId(person.id);
    StringBuffer sb = new StringBuffer();
    person.emails.forEach((PersonEmails personEmail) {
      sb.writeln('${personEmail.type}: ${personEmail.value}');
    });
    status = "Logged in as ${person.displayName}\n${sb}";
  }).catchError((e, st) {
    setErrorStatus('people.get', e, st);
  });
}

Future _inFlow(Future action(BrowserOAuth2Flow flow)) {
  if (_flow == null) {
    return createImplicitBrowserFlow(clientId, scopes).then((BrowserOAuth2Flow flow_) {
      _flow = flow_;
      return action(_flow);
    }).catchError((e, st) {
      setErrorStatus("createImplicitBrowserFlow", e, st);
    });
  } else {
    return action(_flow);
  }
}

main() {
  statusElement = querySelector('#status');
  errorElement = querySelector('#error');
  logInButton = querySelector('#login');
  logInHybridButton = querySelector('#loginhybrid');
  logOutButton = querySelector('#logout');
  status = "Loading...";

  logInButton.onClick.listen((_) {
    _inFlow((BrowserOAuth2Flow flow) {
      return clientViaUserConsent(flow);
    });
  });
  logInHybridButton.onClick.listen((_) {
    _inFlow((BrowserOAuth2Flow flow) {
      flow.runHybridFlow(force: true).then((HybridFlowResult result) {
        onLoggedIn(result.newClient());
      }).catchError((e, st) {
        setErrorStatus("clientViaUserConsent", e, st);
      }).whenComplete(() {

      });
    });
  });

  logOutButton.onClick.listen((_) {
    if (_flow != null) {
      _flow.close();
      _flow = null;
    }
    status = 'logged out (?)'; // well are we really logged out 
  });

  // automatic login
  _inFlow((BrowserOAuth2Flow flow) {
    return clientViaUserConsent(flow, immediate: true, userId: _loadUserId());
  });

}
