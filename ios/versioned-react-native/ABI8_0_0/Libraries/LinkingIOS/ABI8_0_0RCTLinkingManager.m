/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI8_0_0RCTLinkingManager.h"

#import "ABI8_0_0RCTBridge.h"
#import "ABI8_0_0RCTEventDispatcher.h"
#import "ABI8_0_0RCTUtils.h"

NSString *const ABI8_0_0RCTOpenURLNotification = @"ABI8_0_0RCTOpenURLNotification";

@implementation ABI8_0_0RCTLinkingManager

ABI8_0_0RCT_EXPORT_MODULE()

- (void)startObserving
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleOpenURLNotification:)
                                               name:ABI8_0_0RCTOpenURLNotification
                                             object:nil];
}

- (void)stopObserving
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"url"];
}

+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
  NSDictionary<NSString *, id> *payload = @{@"url": URL.absoluteString};
  [[NSNotificationCenter defaultCenter] postNotificationName:ABI8_0_0RCTOpenURLNotification
                                                      object:self
                                                    userInfo:payload];
  return YES;
}

+ (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
  restorationHandler:(void (^)(NSArray *))restorationHandler
{
  if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
    NSDictionary *payload = @{@"url": userActivity.webpageURL.absoluteString};
    [[NSNotificationCenter defaultCenter] postNotificationName:ABI8_0_0RCTOpenURLNotification
                                                        object:self
                                                      userInfo:payload];
  }
  return YES;
}

- (void)handleOpenURLNotification:(NSNotification *)notification
{
  [self sendEventWithName:@"url" body:notification.userInfo];
}

ABI8_0_0RCT_EXPORT_METHOD(openURL:(NSURL *)URL
                  resolve:(ABI8_0_0RCTPromiseResolveBlock)resolve
                  reject:(ABI8_0_0RCTPromiseRejectBlock)reject)
{
  BOOL opened = [ABI8_0_0RCTSharedApplication() openURL:URL];
  if (opened) {
    resolve(nil);
  } else {
    reject(ABI8_0_0RCTErrorUnspecified, [NSString stringWithFormat:@"Unable to open URL: %@", URL], nil);
  }
}

ABI8_0_0RCT_EXPORT_METHOD(canOpenURL:(NSURL *)URL
                  resolve:(ABI8_0_0RCTPromiseResolveBlock)resolve
                  reject:(__unused ABI8_0_0RCTPromiseRejectBlock)reject)
{
  if (ABI8_0_0RCTRunningInAppExtension()) {
    // Technically Today widgets can open urls, but supporting that would require
    // a reference to the NSExtensionContext
    resolve(@NO);
    return;
  }

  // TODO: on iOS9 this will fail if URL isn't included in the plist
  // we should probably check for that and reject in that case instead of
  // simply resolving with NO

  // This can be expensive, so we deliberately don't call on main thread
  BOOL canOpen = [ABI8_0_0RCTSharedApplication() canOpenURL:URL];
  resolve(@(canOpen));
}

ABI8_0_0RCT_EXPORT_METHOD(getInitialURL:(ABI8_0_0RCTPromiseResolveBlock)resolve
                  reject:(__unused ABI8_0_0RCTPromiseRejectBlock)reject)
{
  NSURL *initialURL = nil;
  if (self.bridge.launchOptions[UIApplicationLaunchOptionsURLKey]) {
    initialURL = self.bridge.launchOptions[UIApplicationLaunchOptionsURLKey];
  } else if (&UIApplicationLaunchOptionsUserActivityDictionaryKey &&
             self.bridge.launchOptions[UIApplicationLaunchOptionsUserActivityDictionaryKey]) {
    NSDictionary *userActivityDictionary =
      self.bridge.launchOptions[UIApplicationLaunchOptionsUserActivityDictionaryKey];

    if ([userActivityDictionary[UIApplicationLaunchOptionsUserActivityTypeKey] isEqual:NSUserActivityTypeBrowsingWeb]) {
      initialURL = ((NSUserActivity *)userActivityDictionary[@"UIApplicationLaunchOptionsUserActivityKey"]).webpageURL;
    }
  }
  resolve(ABI8_0_0RCTNullIfNil(initialURL.absoluteString));
}

@end
