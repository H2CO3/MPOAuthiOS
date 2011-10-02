//
//  MPOAuthAPI.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.05.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MPOAuthCredentialStore.h"
#import "MPOAuthParameterFactory.h"

extern NSString * const MPOAuthNotificationAccessTokenReceived;
extern NSString * const MPOAuthNotificationAccessTokenRejected;
extern NSString * const MPOAuthNotificationAccessTokenRefreshed;
extern NSString * const MPOAuthNotificationOAuthCredentialsReady;
extern NSString * const MPOAuthNotificationErrorHasOccurred;

extern NSString * const MPOAuthCredentialRequestTokenKey;
extern NSString * const MPOAuthCredentialRequestTokenSecretKey;
extern NSString * const MPOAuthCredentialAccessTokenKey;
extern NSString * const MPOAuthCredentialAccessTokenSecretKey;
extern NSString * const MPOAuthCredentialSessionHandleKey;

extern NSString * const MPOAuthTokenRefreshDateDefaultsKey;

extern NSString * const MPOAuthBaseURLKey;
extern NSString * const MPOAuthAuthenticationURLKey;

typedef enum {
	MPOAuthSignatureSchemePlainText,
	MPOAuthSignatureSchemeHMACSHA1,
	MPOAuthSignatureSchemeRSASHA1
} MPOAuthSignatureScheme;

typedef enum {
	MPOAuthAuthenticationStateUnauthenticated		= 0,
	MPOAuthAuthenticationStateAuthenticating		= 1,
	MPOAuthAuthenticationStateAuthenticated			= 2
} MPOAuthAuthenticationState;

@protocol MPOAuthAPIInternalClient
@end

@protocol MPOAuthAPIDelegate, MPOAuthAuthenticationMethodOAuthDelegate;

@class MPOAuthAuthenticationMethod;

@interface MPOAuthAPI : NSObject <MPOAuthAPIInternalClient, MPOAuthAuthenticationMethodOAuthDelegate> {
@private
	id <MPOAuthCredentialStore, MPOAuthParameterFactory>		credentials_;
	NSURL *baseURL_;
	NSURL *authenticationURL_;
	MPOAuthAuthenticationMethod *authenticationMethod_;
	MPOAuthSignatureScheme signatureScheme_;
	NSMutableArray *activeLoaders_;
	MPOAuthAuthenticationState oauthAuthenticationState_;
	id <MPOAuthAPIDelegate> delegate_;
}

@property (nonatomic, readonly, retain) id <MPOAuthCredentialStore, MPOAuthParameterFactory> credentials;
@property (nonatomic, readonly, retain) NSURL *baseURL;
@property (nonatomic, readonly, retain) NSURL *authenticationURL;
@property (nonatomic, readwrite, retain) MPOAuthAuthenticationMethod *authenticationMethod;
@property (nonatomic, readwrite, assign) MPOAuthSignatureScheme signatureScheme;

@property (nonatomic, readonly, assign) MPOAuthAuthenticationState authenticationState;

@property(nonatomic, readwrite, assign) id <MPOAuthAPIDelegate> delegate;

- (id)initWithCredentials:(NSDictionary *)inCredentials andBaseURL:(NSURL *)inURL;
- (id)initWithCredentials:(NSDictionary *)inCredentials authenticationURL:(NSURL *)inAuthURL andBaseURL:(NSURL *)inBaseURL;
- (id)initWithCredentials:(NSDictionary *)inCredentials authenticationURL:(NSURL *)inAuthURL andBaseURL:(NSURL *)inBaseURL autoStart:(BOOL)aFlag;
- (id)initWithCredentials:(NSDictionary *)inCredentials withConfiguration:(NSDictionary *)inConfiguration autoStart:(BOOL)aFlag;

- (void)authenticate;
- (BOOL)isAuthenticated;

// Begin H2CO3's additions
// convenience messages
- (void) performGetMethod:(NSString *)method withParameters:(NSDictionary *)parameters target:(id)target action:(SEL)action;
- (void) performGetMethod:(NSString *)method withQuery:(NSString *)query target:(id)taret action:(SEL)action;
- (void) performPostMethod:(NSString *)method withParameters:(NSDictionary *)parameters target:(id)target action:(SEL)action;
- (void) performPostMethod:(NSString *)method withQuery:(NSString *)query target:(id)target action:(SEL)action;

/*
// to be implemented
// support uploading files using
// multipart/form-data encoding
- (void) performPostMethod:(NSString *)method withFilePath:(NSString *)path dataFieldName:(NSString *)name otherParameters:(NSDictionary *)parameters target:(id)target action:(SEL)action;
*/
// End H2CO3's additions

- (void)performMethod:(NSString *)inMethod withTarget:(id)inTarget andAction:(SEL)inAction;
- (void)performMethod:(NSString *)inMethod withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction;
- (void)performMethod:(NSString *)inMethod atURL:(NSURL *)inURL withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction;
- (void)performPOSTMethod:(NSString *)inMethod withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction;
- (void)performPOSTMethod:(NSString *)inMethod atURL:(NSURL *)inURL withParameters:(NSArray *)inParameters withTarget:(id)inTarget andAction:(SEL)inAction;
- (void)performURLRequest:(NSURLRequest *)inRequest withTarget:(id)inTarget andAction:(SEL)inAction;

- (NSData *)dataForMethod:(NSString *)inMethod;
- (NSData *)dataForMethod:(NSString *)inMethod withParameters:(NSArray *)inParameters;
- (NSData *)dataForURL:(NSURL *)inURL andMethod:(NSString *)inMethod withParameters:(NSArray *)inParameters;

- (id)credentialNamed:(NSString *)inCredentialName;
- (void)setCredential:(id)inCredential withName:(NSString *)inName;
- (void)removeCredentialNamed:(NSString *)inName;
- (void)discardCredentials;

@end

@protocol MPOAuthAPIDelegate <NSObject>
@optional
- (void) oauthApi:(MPOAuthAPI *)api receivedAccessToken:(NSString *)token secret:(NSString *)secret;
- (NSURL *) callbackUrlForOAuthApi:(MPOAuthAPI *)api;
- (void) oauthApiFailedToLogIn:(MPOAuthAPI *)api;
@end

