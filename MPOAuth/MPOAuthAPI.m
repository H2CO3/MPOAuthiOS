//
//  MPOAuthAPI.m
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.05.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import "MPOAuthAPIRequestLoader.h"
#import "MPOAuthAPI.h"
#import "MPOAuthCredentialConcreteStore.h"
#import "MPOAuthURLRequest.h"
#import "MPOAuthURLResponse.h"
#import "MPURLRequestParameter.h"
#import "MPOAuthAuthenticationMethod.h"

#import "NSURL+MPURLParameterAdditions.h"

NSString *kMPOAuthCredentialConsumerKey = @"kMPOAuthCredentialConsumerKey";
NSString *kMPOAuthCredentialConsumerSecret = @"kMPOAuthCredentialConsumerSecret";
NSString *kMPOAuthCredentialUsername = @"kMPOAuthCredentialUsername";
NSString *kMPOAuthCredentialPassword = @"kMPOAuthCredentialPassword";
NSString *kMPOAuthCredentialRequestToken = @"kMPOAuthCredentialRequestToken";
NSString *kMPOAuthCredentialRequestTokenSecret = @"kMPOAuthCredentialRequestTokenSecret";
NSString *kMPOAuthCredentialAccessToken = @"kMPOAuthCredentialAccessToken";
NSString *kMPOAuthCredentialAccessTokenSecret = @"kMPOAuthCredentialAccessTokenSecret";
NSString *kMPOAuthCredentialSessionHandle = @"kMPOAuthCredentialSessionHandle";

NSString *kMPOAuthSignatureMethod = @"kMPOAuthSignatureMethod";
NSString * const MPOAuthTokenRefreshDateDefaultsKey = @"MPOAuthAutomaticTokenRefreshLastExpiryDate";

NSString * const MPOAuthBaseURLKey = @"MPOAuthBaseURL";
NSString * const MPOAuthAuthenticationURLKey = @"MPOAuthAuthenticationURL";

@interface MPOAuthAPI ()
@property (nonatomic, readwrite, retain) id <MPOAuthCredentialStore, MPOAuthParameterFactory> credentials;
@property (nonatomic, readwrite, retain) NSURL *authenticationURL;
@property (nonatomic, readwrite, retain) NSURL *baseURL;
@property (nonatomic, readwrite, retain) NSMutableArray *activeLoaders;
@property (nonatomic, readwrite, assign) MPOAuthAuthenticationState authenticationState;

- (void)performMethod:(NSString *)inMethod atURL:(NSURL *)inURL withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction usingHTTPMethod:(NSString *)inHTTPMethod;
- (NSURL *) callbackURLForCompletedUserAuthorization;
@end

@implementation MPOAuthAPI

- (id)initWithCredentials:(NSDictionary *)inCredentials andBaseURL:(NSURL *)inBaseURL {
	self = [self initWithCredentials:inCredentials authenticationURL:inBaseURL andBaseURL:inBaseURL];
	return self;
}

- (id)initWithCredentials:(NSDictionary *)inCredentials authenticationURL:(NSURL *)inAuthURL andBaseURL:(NSURL *)inBaseURL {
	self = [self initWithCredentials:inCredentials authenticationURL:inBaseURL andBaseURL:inBaseURL autoStart:NO];
	return self;
}

- (id)initWithCredentials:(NSDictionary *)inCredentials authenticationURL:(NSURL *)inAuthURL andBaseURL:(NSURL *)inBaseURL autoStart:(BOOL)aFlag {
	if ((self = [super init])) {
		self.authenticationURL = inAuthURL;
		self.baseURL = inBaseURL;
		credentials_ = [[MPOAuthCredentialConcreteStore alloc] initWithCredentials:inCredentials forBaseURL:inBaseURL withAuthenticationURL:inAuthURL];
		self.authenticationMethod = [[[MPOAuthAuthenticationMethod alloc] initWithAPI:self forURL:inAuthURL] autorelease];
		self.signatureScheme = MPOAuthSignatureSchemeHMACSHA1;
		activeLoaders_ = [[NSMutableArray alloc] init];
		// Begin H2CO3's additions
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestTokenReceivedInternal:) name:MPOAuthNotificationRequestTokenReceived object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessTokenReceivedInternal:) name:MPOAuthNotificationAccessTokenReceived object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessTokenRejectedInternal:) name:MPOAuthNotificationAccessTokenRejected object:nil];
		NSDictionary *savedCredentials = [[NSUserDefaults standardUserDefaults] objectForKey:@"MPOAuthSavedCredentials"];
		NSDictionary *credentials = [savedCredentials objectForKey:[self.baseURL absoluteString]];
		NSString *accessToken = [credentials objectForKey:@"oauth_token"];
		NSString *accessTokenSecret = [credentials objectForKey:@"oauth_token_secret"];
		if (accessToken && accessTokenSecret) {
			[self setCredential:accessToken withName:kMPOAuthCredentialAccessToken];
			[self setCredential:accessTokenSecret withName:kMPOAuthCredentialAccessTokenSecret];
			self.authenticationState = MPOAuthAuthenticationStateAuthenticated;
		} else {
			self.authenticationState = MPOAuthAuthenticationStateUnauthenticated;
		}
		// End H2CO3's additions
		if (aFlag) {
			[self authenticate];
		}
	}
	return self;	
}

- (id)initWithCredentials:(NSDictionary *)inCredentials withConfiguration:(NSDictionary *)inConfiguration autoStart:(BOOL)aFlag {
	if ((self = [super init])) {
		self.authenticationURL = [inConfiguration valueForKey:MPOAuthAuthenticationURLKey];
		self.baseURL = [inConfiguration valueForKey:MPOAuthBaseURLKey];
		self.authenticationState = MPOAuthAuthenticationStateUnauthenticated;
		credentials_ = [[MPOAuthCredentialConcreteStore alloc] initWithCredentials:inCredentials forBaseURL:self.baseURL withAuthenticationURL:self.authenticationURL];
		self.authenticationMethod = [[MPOAuthAuthenticationMethod alloc] initWithAPI:self forURL:self.authenticationURL withConfiguration:inConfiguration];				
		self.signatureScheme = MPOAuthSignatureSchemeHMACSHA1;
		
		activeLoaders_ = [[NSMutableArray alloc] initWithCapacity:10];
		
		if (aFlag) {
			[self authenticate];
		}
	}
	return self;	
}

- (oneway void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	self.credentials = nil;
	self.baseURL = nil;
	self.authenticationURL = nil;
	self.authenticationMethod = nil;
	self.activeLoaders = nil;
	[super dealloc];
}

// Begin H2CO3's additions

- (NSURL *) callbackURLForCompletedUserAuthorization {
	// ask our delegate
	return [delegate_ callbackUrlForOAuthApi:self];
}

- (void) requestTokenReceivedInternal:(NSNotification *)notification {
	NSString *oauthConfigPath = [[NSBundle mainBundle] pathForResource:@"MPOAuthServiceProviderConfiguration" ofType:@"plist"];
	NSDictionary *oauthConfigDictionary = [NSDictionary dictionaryWithContentsOfFile:oauthConfigPath];
	NSDictionary *oauthConfig = nil;
	for (NSString *domainString in [oauthConfigDictionary keyEnumerator]) {
		if ([self.baseURL domainMatches:domainString]) {
			oauthConfig = [oauthConfigDictionary objectForKey:domainString];
			break;
		}
	}
	NSURL *authorizeUrl = nil;
	if (oauthConfig != nil) {
		NSDictionary *methodUrls = [oauthConfig objectForKey:@"MPOAuthAuthenticationMethodOAuth"];
		if (methodUrls != nil) {
			NSString *authorizeUrlString = [methodUrls objectForKey:@"MPOAuthUserAuthorizationURL"];
			if (authorizeUrlString != nil) {
				authorizeUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@?oauth_token=%@", authorizeUrlString, [[notification userInfo] objectForKey:@"oauth_token"]]];
				[[UIApplication sharedApplication] openURL:authorizeUrl];
			}
		}
	}
}

- (void) accessTokenReceivedInternal:(NSNotification *)notification {
	NSString *accessToken = [[notification userInfo] objectForKey:@"oauth_token"];
	NSString *accessTokenSecret = [[notification userInfo] objectForKey:@"oauth_token_secret"];
	NSMutableDictionary *credentials = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:@"MPOAuthSavedCredentials"]];
	[credentials setObject:[NSDictionary dictionaryWithObjectsAndKeys:accessToken, @"oauth_token", accessTokenSecret, @"oauth_token_secret", nil] forKey:[self.baseURL absoluteString]];
	[[NSUserDefaults standardUserDefaults] setObject:credentials forKey:@"MPOAuthSavedCredentials"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	if([delegate_ respondsToSelector:@selector(oauthApi:receivedAccessToken:secret:)]) {
		[delegate_ oauthApi:self receivedAccessToken:accessToken secret:accessTokenSecret];
	}
}

- (void) accessTokenRejectedInternal:(NSNotification *)notification {
	if([delegate_ respondsToSelector:@selector(oauthApiFailedToLogIn:)]) {
		[delegate_ oauthApiFailedToLogIn:self];
	}
}

// End H2CO3's additions

@synthesize credentials = credentials_;
@synthesize baseURL = baseURL_;
@synthesize authenticationURL = authenticationURL_;
@synthesize authenticationMethod = authenticationMethod_;
@synthesize signatureScheme = signatureScheme_;
@synthesize activeLoaders = activeLoaders_;
@synthesize authenticationState = oauthAuthenticationState_;
@synthesize delegate = delegate_;

#pragma mark -

- (void)setSignatureScheme:(MPOAuthSignatureScheme)inScheme {
	signatureScheme_ = inScheme;
	NSString *methodString = nil;
	switch (signatureScheme_) {
		case MPOAuthSignatureSchemePlainText:
			methodString = @"PLAINTEXT";
			break;
		case MPOAuthSignatureSchemeRSASHA1:
			methodString = @"RSA-SHA1";
			break;
		case MPOAuthSignatureSchemeHMACSHA1:
		default:
			methodString = @"HMAC-SHA1";
			break;
	}
	[(MPOAuthCredentialConcreteStore *)credentials_ setSignatureMethod:methodString];
}

#pragma mark -

- (void)authenticate {
	NSAssert(credentials_.consumerKey, @"A Consumer Key is required for use of OAuth.");
	[self.authenticationMethod authenticate];
}

- (BOOL)isAuthenticated {
	return (self.authenticationState == MPOAuthAuthenticationStateAuthenticated);
}

#pragma mark -

// Begin H2CO3's additions

// convenience messages

- (void) performGetMethod:(NSString *)method withParameters:(NSDictionary *)parameters target:(id)target action:(SEL)action {
	NSArray *requestParameters = [MPURLRequestParameter parametersFromDictionary:parameters];
	[self performMethod:method withParameters:requestParameters withTarget:target andAction:action];
}

- (void) performGetMethod:(NSString *)method withQuery:(NSString *)query target:(id)target action:(SEL)action {
	NSArray *requestParameters = [MPURLRequestParameter parametersFromString:query];
	[self performMethod:method withParameters:requestParameters withTarget:target andAction:action];
}

- (void) performPostMethod:(NSString *)method withParameters:(NSDictionary *)parameters target:(id)target action:(SEL)action {
	NSArray *requestParameters = [MPURLRequestParameter parametersFromDictionary:parameters];
	[self performPOSTMethod:method withParameters:requestParameters withTarget:target andAction:action];
}

- (void) performPostMethod:(NSString *)method withQuery:(NSString *)query target:(id)target action:(SEL)action {
	NSArray *requestParameters = [MPURLRequestParameter parametersFromString:query];
	[self performPOSTMethod:method withParameters:requestParameters withTarget:target andAction:action];
}

/*
// to be implemented
// support uploading files using
// multipart/form-data encoding
- (void) performPostMethod:(NSString *)method withFilePath:(NSString *)path dataFieldName:(NSString *)name otherParameters:(NSDictionary *)parameters target:(id)target action:(SEL)action;
*/

// End H2CO3's additions

- (void)performMethod:(NSString *)inMethod withTarget:(id)inTarget andAction:(SEL)inAction {
	[self performMethod:inMethod atURL:self.baseURL withParameters:nil withTarget:inTarget andAction:inAction usingHTTPMethod:@"GET"];
}

- (void)performMethod:(NSString *)inMethod withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction {
	[self performMethod:inMethod atURL:self.baseURL withParameters:inParameters withTarget:inTarget andAction:inAction usingHTTPMethod:@"GET"];
}

- (void)performMethod:(NSString *)inMethod atURL:(NSURL *)inURL withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction {
	[self performMethod:inMethod atURL:inURL withParameters:inParameters withTarget:inTarget andAction:inAction usingHTTPMethod:@"GET"];
}

- (void)performPOSTMethod:(NSString *)inMethod withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction {
	[self performPOSTMethod:inMethod atURL:self.baseURL withParameters:inParameters withTarget:inTarget andAction:inAction];
}

- (void)performPOSTMethod:(NSString *)inMethod atURL:(NSURL *)inURL withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction {
	[self performMethod:inMethod atURL:inURL withParameters:inParameters withTarget:inTarget andAction:inAction usingHTTPMethod:@"POST"];
}

- (void)performMethod:(NSString *)inMethod atURL:(NSURL *)inURL withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction usingHTTPMethod:(NSString *)inHTTPMethod {
	if (!inMethod && ![inURL path] && ![inURL query]) {
		[NSException raise:@"MPOAuthNilMethodRequestException" format:@"Nil was passed as the method to be performed on %@", inURL];
	}
	
	NSURL *requestURL = inMethod ? [NSURL URLWithString:inMethod relativeToURL:inURL] : inURL;
	MPOAuthURLRequest *aRequest = [[MPOAuthURLRequest alloc] initWithURL:requestURL andParameters:inParameters];
	MPOAuthAPIRequestLoader *loader = [[MPOAuthAPIRequestLoader alloc] initWithRequest:aRequest];
	
	aRequest.HTTPMethod = inHTTPMethod;
	loader.credentials = self.credentials;
	loader.target = inTarget;
	loader.action = inAction ? inAction : @selector(_performedLoad:receivingData:);
	
	[loader loadSynchronously:NO];
	
	[loader release];
	[aRequest release];
}

- (void)performURLRequest:(NSURLRequest *)inRequest withTarget:(id)inTarget andAction:(SEL)inAction {
	if (!inRequest && ![[inRequest URL] path] && ![[inRequest URL] query]) {
		[NSException raise:@"MPOAuthNilMethodRequestException" format:@"Nil was passed as the method to be performed on %@", inRequest];
	}

	MPOAuthURLRequest *aRequest = [[MPOAuthURLRequest alloc] initWithURLRequest:inRequest];
	MPOAuthAPIRequestLoader *loader = [[MPOAuthAPIRequestLoader alloc] initWithRequest:aRequest];
	
	loader.credentials = self.credentials;
	loader.target = inTarget;
	loader.action = inAction ? inAction : @selector(_performedLoad:receivingData:);
	
	[loader loadSynchronously:NO];
	
	[loader release];
	[aRequest release];	
}

- (NSData *)dataForMethod:(NSString *)inMethod {
	return [self dataForURL:self.baseURL andMethod:inMethod withParameters:nil];
}

- (NSData *)dataForMethod:(NSString *)inMethod withParameters:(NSArray *)inParameters {
	return [self dataForURL:self.baseURL andMethod:inMethod withParameters:inParameters];
}

- (NSData *)dataForURL:(NSURL *)inURL andMethod:(NSString *)inMethod withParameters:(NSArray *)inParameters {
	NSURL *requestURL = [NSURL URLWithString:inMethod relativeToURL:inURL];
	MPOAuthURLRequest *aRequest = [[MPOAuthURLRequest alloc] initWithURL:requestURL andParameters:inParameters];
	MPOAuthAPIRequestLoader *loader = [[MPOAuthAPIRequestLoader alloc] initWithRequest:aRequest];

	loader.credentials = self.credentials;
	[loader loadSynchronously:YES];
	
	[loader autorelease];
	[aRequest release];
	
	return loader.data;
}

#pragma mark -

- (id)credentialNamed:(NSString *)inCredentialName {
	return [self.credentials credentialNamed:inCredentialName];
}

- (void)setCredential:(id)inCredential withName:(NSString *)inName {
	[(MPOAuthCredentialConcreteStore *)self.credentials setCredential:inCredential withName:inName];
}

- (void)removeCredentialNamed:(NSString *)inName {
	[(MPOAuthCredentialConcreteStore *)self.credentials removeCredentialNamed:inName];
}

- (void)discardCredentials {
	[self.credentials discardOAuthCredentials];	
	self.authenticationState = MPOAuthAuthenticationStateUnauthenticated;
}

#pragma mark -
#pragma mark - Private APIs -

- (void)_performedLoad:(MPOAuthAPIRequestLoader *)inLoader receivingData:(NSData *)inData {
	// NSLog(@"loaded %@, and got %@", inLoader, inData);
}

@end

