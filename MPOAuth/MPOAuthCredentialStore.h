//
//  MPOAuthCredentialStore.h
//  MPOAuthConnection
//
//  Created by Karl Adam on 08.12.06.
//  Copyright 2008 matrixPointer. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *kMPOAuthCredentialConsumerKey;
extern NSString *kMPOAuthCredentialConsumerSecret;
extern NSString *kMPOAuthCredentialUsername;
extern NSString *kMPOAuthCredentialPassword;
extern NSString *kMPOAuthCredentialRequestToken;
extern NSString *kMPOAuthCredentialRequestTokenSecret;
extern NSString *kMPOAuthCredentialAccessToken;
extern NSString *kMPOAuthCredentialAccessTokenSecret;
extern NSString *kMPOAuthCredentialSessionHandle;
extern NSString *kMPOAuthCredentialRealm;

@protocol MPOAuthCredentialStore <NSObject>

@property (nonatomic, readonly) NSString *consumerKey;
@property (nonatomic, readonly) NSString *consumerSecret;
@property (nonatomic, readonly) NSString *username;
@property (nonatomic, readonly) NSString *password;
@property (nonatomic, readonly, retain) NSString *requestToken;
@property (nonatomic, readonly, retain) NSString *requestTokenSecret;
@property (nonatomic, readonly, retain) NSString *accessToken;
@property (nonatomic, readonly, retain) NSString *accessTokenSecret;

- (void) setAccessToken:(NSString *)token;
- (void) setAccessTokenSecret:(NSString *)secret;
- (void) setRequestToken:(NSString *)token;
- (void) setRequestTokenSecret:(NSString *)secret;

- (NSString *)credentialNamed:(NSString *)inCredentialName;
- (void)discardOAuthCredentials;

@end

