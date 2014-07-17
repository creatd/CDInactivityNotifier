//
//  CDInactivityNotifier.h
//  CDInactivityNotifier
//
//  Copyright (c) 2014 Creatd. Use as you wish.
//  creatd.co.uk

#import <Foundation/Foundation.h>

@protocol CDInactivityNotifierListener <NSObject>

@required

/**
 Called to notify a certain duration of no interaction.
 Listeners have to subscribe to receive this callback and will receive it once on (or slightly after) the configured duration
 */
- (void)userDidNotInteractFor:(NSTimeInterval)duration;

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
+ (void)activate;

/**
 Adds listener for specified duration of inactivity.
 Listener will receive a callback when there is no user interaction with the device for specified duration.
 NOTE- It will be active after user first interacts with the device
 */
+ (void)subscribeListener:(id<CDInactivityNotifierListener, NSCoding>)listener forDuration:(NSTimeInterval)duration;

/**
 Unsubscribes listener from further notifications.
 Note that this will remove all subscriptions by the same sender.
 */
+ (void)unsubscribeListener:(id<CDInactivityNotifierListener, NSCoding>)listener;

/**
 Deactivates notifier so no detection is carried out and no notifications are produced.
 */
+ (void)deactivate;

/**
 Pauses detection for specified duration. Note that this affects all subscribers.
 When it's activated again, it will start from beginning.
 */
+ (void)disableFor:(NSTimeInterval)duration;

@end
