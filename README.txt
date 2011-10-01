An implementation of MPOAuth that actually works on iOS.
/* To be documented properly shortly. */
Thanks for Carl Adam for making the otherwise awesome MPOAuth library.
License: CreativeCommons Attirbution Unported 3.0 License

How to use this stuff:
----------------------

1. Create an instance initted to a. either one of the default/recognized base URLs (examples: twitter, yahoo, google, foursquare etc. see MPOAuthServiceProviderConfiguration.plist)
or b. a base URL and an auth URL:
#import <MPOAuth/MPOAuth.h>

NSDictionary *appCredentials = [NSDictionary dictionaryWithObjectsAndKeys:@"ApPcOnSuMeRkEy", kMPOAuthCredentialConsumerKey, @"OAuthApPsEcReTkEy", kMPOAuthCredentialConsumerSecret, nil];
MPOAuthAPI *client = [[MPOAuthAPI alloc] initWithCredentials:appCredentials andBaseURL:[NSURL URLWithString:@"https://api.twitter.com/"]];
client.delegate = self; // e. g. your view controller

2. In your delegate, provide the callback URL to the API. This will be passed along with the OAuth access token & secret when the user
authorizes your app.

- (NSURL *) callbackUrlForOAuthApi:(MPOAuthAPI *)api {
	NSURL *url = [NSURL URLWithString:@"myapp-oauth-callback://twitter"];
	return url;
}

3. When you need the OAuth access, check if you've already got it; if not, start the dance:

	if ([client isAuthenticated]) {
		// do whatever you want *
	} else {
		[client authenticate];
	}
}

Now the client will acquire the request token, then it will open the authentication URL in Safari. When the user authorizes your app,
the service (hopefully) will redirect him/her to your app via the custom URL scheme along with the request token & secret & verifier
(myapp-oauth-callback://twitter?oauth_token=sOmEOAuthToKeNyOuGoT&oauth_token_secret=wHaTeVeRrAnDoMsTuFf)
You'll need to handle this in your application:handleOpenURL: method in your app delegate, as the following:

- (BOOL) application:(UIApplication *)sharedApplication handleOpenURL:(NSURL *)openUrl {
	// check whether or not it's an OAuth callback redirect URL
	if ([[openUrl scheme] isEqualToString:@"myapp-oauth-callback"]) {
		// OAuth callback!!! parse the parameters
		NSString *q = [openUrl query];
		NSArray *paramsArray = [q componentsSeparatedByString:@"&"];
		NSMutableDictionary *params = [NSMutableDictionary dictionary];
		for (NSString *keyValuePair in paramsArray) {
			NSArray *param = [keyValuePair componentsSeparatedByString:@"="];
			[params setObject:[param objectAtIndex:0] forKey:[param objectAtIndex:1]];
		}
		// params now contains the oauth_token and oauth_token_secret, so pass it on the OAuth API instance
		[client setCredential:[params objectForKey:@"oauth_token"] withName:MPOAuthCredentialAccessTokenKey];
		[client setCredential:[params objectForKey:@"oauth_token_secret"] withName:MPOAuthCredentialAccessTokenSecretKey];
		// and let it know that it needs to conitnue the dance
		[client authenticate]; // yes, the same method again
	} else {
		// some other things happened, unrelated to OAuth
		[self doSomethingWithThe:openUrl];
	}
	return YES;
}

3. If you've done this, the API will ask the service for the access token and then notify you that it got the tokens in it's delegate's oauthApi:receivedAccesToken:secret: method.
The API will smartly store the tokens, so you don't have to authorize it when your app has to be restarted.
You can log out using [client discardCredentials]; after.

* To actually do something useful with the API/client, you'll need to perform either GET or POST methods to the API's resource URLs, with the proper parameters
(abstractly implemented by the MPURLRequestParameter class - it creates an array of parameter objects from a GET-format URL query string):
For example, you do so to update a user's status on Twitter:
	NSArray *params = [MPURLRequestParameter parametersFromString:[NSString stringWithFormat:@"status=%@", @"Hey! Just posted a tweet from my iOS app!"]];
	[client performPOSTMethod:@"/1/statuses/update.json" withParameters:params withTarget:self andAction:@selector(twitterStatusUpdateSent)];

and in the delegate:
- (void) twitterStatusUpdateSent {
	UIAlertView *av = [UIAlertView new];
	av.title = @"Tweet sent";
	[av addButtonWithTitle:@"Dismiss"];
	[av show];
	[av release];
}

Well, that's all you need to know about MPOAuthAPI.

TODOs:
 - implement a method on MPOAuthAPI that works with a dictionary as params
 - support multipart/form-data methods for POST methods to enable uploading files (images to Twitter, sound files to soundcloud etc.)
