//
//  CDInactivityNotifier.h
//  CDInactivityNotifier
//
//  Copyright (c) 2014 Creatd. Use as you wish.
//  creatd.co.uk

#import <Foundation/Foundation.h>

// TODO- Doesn't work with scroll views (e.g. if I'm scrolling a scroll view, it won't detect my interaction and might mistakenly think I haven't interacted for a while)
// TODO- Inheriting UIApplication to intercept sendEvent might be a better idea (see here http://stackoverflow.com/questions/8085188/ios-perform-action-after-period-of-inactivity-no-user-interaction)

/**
 Protocol to receive callbacks from CDInactivityNotifier
 NOTE- Do not make any assumptions regarding threads on which callbacks will be delivered
 */
@protocol CDInactivityNotifierListener <NSObject>

@required

/**
 Called to notify a certain duration of no interaction.
 Listeners have to subscribe to receive this callback and will receive it once on (or slightly after) the configured duration
 */
- (void)userDidNotInteractFor:(NSTimeInterval)duration key:(NSString *)key;

@optional

/**
 Called when user interacts with the device
 */
- (void)userInteracted;

@end

@interface CDInactivityNotifier : NSObject

/////////////////////////////////////////////////////////////////////////
#pragma mark - Public methods
/////////////////////////////////////////////////////////////////////////

/**
 Adds and starts the notifier. This must be used for initialisation.
 */
+ (void)enable;

/**
 Adds listener for specified duration of inactivity.
 Listener will receive a callback when there is no user interaction with the device for specified duration.
 @param key - Key to be passed back with callback, optional.
 NOTE- It will be active after user first interacts with the device
 NOTE- If key already exists, it will append (i.e. add one more time for notifying).
 */
+ (void)subscribeListener:(id<CDInactivityNotifierListener>)listener forDuration:(NSTimeInterval)duration withKey:(NSString *)key;

/**
 Unsubscribes listener from further notifications.
 Note that this will remove all subscriptions by the same sender.
 */
+ (void)unsubscribeListener:(id<CDInactivityNotifierListener>)listener;

/**
 Unsubscribes listener for notifications registered using specified key.
 */
+ (void)unsubscribeListener:(id<CDInactivityNotifierListener>)listener withKey:(NSString *)key;

/**
 Disables notifier so no detection is carried out and no notifications are produced.
 All registered observers are preserved but made inactive.
 */
+ (void)disable;

/**
 Pauses detection for specified duration. Note that this affects all subscribers.
 When it's activated again, it will reset time back to beginning.
 */
+ (void)disableFor:(NSTimeInterval)duration;

/**
 Mimic a touch on the screen
 (Workaround for cases when touches are not detected by CDInactivityNotifier such as when there is a window above it)
 
 TODO- You shouldn't need this method
 */
+ (void)nudge;

@end
