//
//  CDInactivityNotifier.m
//  CDInactivityNotifier
//
//  Copyright (c) 2014 Creatd. Use as you wish.
//  creatd.co.uk

#import "CDInactivityNotifier.h"

// Framework
#import <MediaPlayer/MPMoviePlayerController.h>

@interface CDStickyTransparentView : UIView

/////////////////////////////////////////////////////////////////////////
#pragma mark - Public methods
/////////////////////////////////////////////////////////////////////////

/**
 Adds transparent view to the top of the key window
 */
- (void)add;

/**
 Removes transparent view from key window
 */
- (void)remove;

/////////////////////////////////////////////////////////////////////////
#pragma mark - Public properties
/////////////////////////////////////////////////////////////////////////

/**
 Block that gets executed when user interaction with this view begins
 
 Note - Currently, interactionEnded block is not supported
 */
@property (nonatomic, copy) void(^interactionBegan)();

/**
 Returns whether this view is currently added to the key window
 */
@property(nonatomic, assign) BOOL isAdded;

@end

@implementation CDStickyTransparentView

const static NSString *kkCDStickyTransparentViewNilKey = @"kkCDStickyTransparentViewNilKey";

/////////////////////////////////////////////////////////////////////////
#pragma mark - Public methods
/////////////////////////////////////////////////////////////////////////

- (void)add {
    if (self.isAdded) {
        NSLog(@"Warning - Won't add transparent view, it's already added");
        return;
    }
    
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(add) withObject:nil waitUntilDone:NO];
        return;
    }
    
    UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
    if (!mainWindow) {
        [self performSelector:@selector(add) withObject:nil afterDelay:.1];
        return;
    }
    [mainWindow insertSubview:self aboveSubview:mainWindow];
    
    self.isAdded = YES;
}

- (void)remove {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(remove) withObject:nil waitUntilDone:NO];
        return;
    }
    
    if (!self.isAdded) {
        NSLog(@"Warning - Removing an already removed transparent view");
    }
    
    [self removeFromSuperview];
    self.isAdded = NO;
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - View lifecycle
/////////////////////////////////////////////////////////////////////////

- (id)init {
    CGRect frame = [UIApplication sharedApplication].keyWindow.bounds;
    if (self = [super initWithFrame:frame]) {

        /////////////////////////////////////////
        // Init properties
        /////////////////////////////////////////

        self.isAdded = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.clipsToBounds = YES;
    }
    return self;
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - Default methods
/////////////////////////////////////////////////////////////////////////

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    // Handle event
    if (event.type == UIEventTypeTouches) {
        if (self.interactionBegan) {
            self.interactionBegan();
        }
    }
    
    // Pass it along
    UIView *viewNext = [[[[UIApplication sharedApplication] keyWindow] subviews] objectAtIndex:0];
    CGPoint pointConverted = [self.layer convertPoint:point toLayer:viewNext.layer];
    return [viewNext hitTest:pointConverted withEvent:event];
}

@end


@interface CDInactivityNotifier()<UIGestureRecognizerDelegate> {
    // UI
    CDStickyTransparentView *_viewSticky;
    
    // Time-related
    NSTimeInterval _timestampLastInteraction;
    NSTimer *_timerTimeout;
    NSTimeInterval _shortestTimeoutDuration; // Shortest duration that is configured
    NSMapTable *_listenerSubscriptionTimes; // Mapping listener objects to a dictionary of durations (key: key or special null -> value: array of durations)
    NSTimeInterval _lastNotifiedLongestDuration; // Longest subscribed duration that was notified in the last notification iteration

    // Flags
    BOOL _isInterestedInUserInteracted; // YES if there is at least one listener interested in userInteracted callback method (for performance reasons)

    // Race condition prevention
    // To coordinate access to _listenerSubscriptionTimes var
    dispatch_queue_t _q;
}

@end

@implementation CDInactivityNotifier

/////////////////////////////////////////////////////////////////////////
#pragma mark - Public methods
/////////////////////////////////////////////////////////////////////////

+ (void)activate {
    return [[self sharedInstance] activate];
}

- (void)activate {
    _q = dispatch_queue_create("CDInactivityNotifier", NULL);
    dispatch_async(_q, ^{
        [self setup];
        [self activateTimeout];
    });
    return;
}

+ (void)subscribeListener:(id<CDInactivityNotifierListener>)listener forDuration:(NSTimeInterval)duration withKey:(NSString *)key {
    if (duration < 1) {
        NSLog(@"Error - Cannot add listener for less than 1 second (%f)",duration);
        return;
    }
    else if (![listener conformsToProtocol:@protocol(CDInactivityNotifierListener)]) {
        NSLog(@"Error - Listener does not conform to CDInactivityNotifierListener protocol");
        return;
    }
    return [[self sharedInstance] subscribeListener:listener forDuration:duration withKey:key];
}

- (void)subscribeListener:(id<CDInactivityNotifierListener>)listener forDuration:(NSTimeInterval)duration withKey:(NSString *)key {
    dispatch_async(_q, ^{
        if (!_listenerSubscriptionTimes) {
            _listenerSubscriptionTimes = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory];
        }
        
        if (_shortestTimeoutDuration < 0 || duration < _shortestTimeoutDuration) {
            _shortestTimeoutDuration = duration;
            [self activateTimeout];
        }
        
        NSString *keyAdjusted = key;
        if (keyAdjusted.length <= 0) {
            keyAdjusted = [NSString stringWithString:kkCDStickyTransparentViewNilKey];
        }
        
        NSDictionary *dictTimes = [_listenerSubscriptionTimes objectForKey:listener];
        if (dictTimes) {
            NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:dictTimes];
            NSArray *arrTimesForKey = [dictTimes objectForKey:keyAdjusted];
            if (arrTimesForKey) {
                NSMutableArray *newArr = [NSMutableArray arrayWithArray:arrTimesForKey];
                [newArr addObject:[NSNumber numberWithFloat:duration]];
                [newDict setObject:newArr forKey:keyAdjusted];
            }
            else {
                [newDict setObject:@[[NSNumber numberWithFloat:duration]] forKey:keyAdjusted];
            }
            [_listenerSubscriptionTimes setObject:newDict forKey:listener];
        }
        else {
            NSDictionary *newDict = @{
                                      keyAdjusted: @[[NSNumber numberWithFloat:duration]]
                                      };
            [_listenerSubscriptionTimes setObject:newDict forKey:listener];
        }
        
        if (!_isInterestedInUserInteracted && [listener respondsToSelector:@selector(userInteracted)]) {
            _isInterestedInUserInteracted = YES;
        }
    });
}

+ (void)unsubscribeListener:(id<CDInactivityNotifierListener>)listener {

    return [[self sharedInstance] unsubscribeListener:listener];
}

- (void)unsubscribeListener:(id<CDInactivityNotifierListener>)listener {
    dispatch_async(_q, ^{
        [_listenerSubscriptionTimes removeObjectForKey:listener];
        
        // Recalculate shortest duration time
        NSTimeInterval shortestDuration = -1;
        for (id<CDInactivityNotifierListener> otherListener in _listenerSubscriptionTimes) {
            NSDictionary *dictTimes = [_listenerSubscriptionTimes objectForKey:otherListener];
            
            for (NSString *key in dictTimes) {
                NSArray *arrTimesForKey = [dictTimes objectForKey:key];
                
                for (NSNumber *time in arrTimesForKey) {
                    if (shortestDuration == -1 || time.floatValue < shortestDuration) {
                        shortestDuration = time.floatValue;
                    }
                }
            }
        }
        
        if (shortestDuration != _shortestTimeoutDuration) {
            // Configure timer again
            [self activateTimeout];
        }
        
        // Recalculate isInterestedInUserInteracted
        if (_isInterestedInUserInteracted && [listener respondsToSelector:@selector(userInteracted)]) {
            
            // Check if there is another listener interested in this callback
            BOOL anotherExists = NO;
            for (id<CDInactivityNotifierListener> otherListener in _listenerSubscriptionTimes) {
                if ([otherListener respondsToSelector:@selector(userInteracted)]) {
                    anotherExists = YES;
                    break;
                }
            }
            if (!anotherExists) {
                _isInterestedInUserInteracted = NO;
            }
        }
    });
}

+ (void)unsubscribeListener:(id<CDInactivityNotifierListener>)listener withKey:(NSString *)key {
    return [[self sharedInstance] unsubscribeListener:listener withKey:key];
}

- (void)unsubscribeListener:(id<CDInactivityNotifierListener>)listener withKey:(NSString *)key {
    dispatch_async(_q, ^{
        NSDictionary *dictTimes = [_listenerSubscriptionTimes objectForKey:listener];
        NSString *keyAdjusted = key;
        if (keyAdjusted.length <= 0) {
            keyAdjusted = [NSString stringWithFormat:@"%@",kkCDStickyTransparentViewNilKey];
        }
        NSArray *arrTimes = [dictTimes objectForKey:keyAdjusted];
        
        if (arrTimes.count > 0) {
            NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:dictTimes];
            [newDict removeObjectForKey:keyAdjusted];
            [_listenerSubscriptionTimes setObject:newDict forKey:listener];
        }
        
        // Recalculate shortest duration time
        NSTimeInterval shortestDuration = -1;
        for (id<CDInactivityNotifierListener> otherListener in _listenerSubscriptionTimes) {
            NSDictionary *dictTimes = [_listenerSubscriptionTimes objectForKey:otherListener];
            
            for (NSString *key in dictTimes) {
                NSArray *arrTimesForKey = [dictTimes objectForKey:key];
                
                for (NSNumber *time in arrTimesForKey) {
                    if (shortestDuration == -1 || time.floatValue < shortestDuration) {
                        shortestDuration = time.floatValue;
                    }
                }
            }
        }
        
        if (shortestDuration != _shortestTimeoutDuration) {
            // Configure timer again
            [self activateTimeout];
        }
        
        // Recalculate isInterestedInUserInteracted
        if (_isInterestedInUserInteracted && [listener respondsToSelector:@selector(userInteracted)]) {
            
            // Check if there is another listener interested in this callback
            BOOL anotherExists = NO;
            for (id<CDInactivityNotifierListener> otherListener in _listenerSubscriptionTimes) {
                if ([otherListener respondsToSelector:@selector(userInteracted)]) {
                    anotherExists = YES;
                    break;
                }
            }
            if (!anotherExists) {
                _isInterestedInUserInteracted = NO;
            }
        }
    });
}

+ (void)deactivate {
    [[CDInactivityNotifier sharedInstance] deactivate];
}

- (void)deactivate {
    dispatch_async(_q, ^{
        [_timerTimeout invalidate];
        _timerTimeout = nil;
        
        [_viewSticky remove];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    });
}

+ (void)disableFor:(NSTimeInterval)duration {
    [[CDInactivityNotifier sharedInstance] disableFor:duration];
}

- (void)disableFor:(NSTimeInterval)duration {
    _timestampLastInteraction = [self.class now] + duration;
}

+ (void)nudge {
    [[self sharedInstance] nudge];
}

- (void)nudge {
    _timestampLastInteraction = [self.class now];
    _lastNotifiedLongestDuration = -1;
    
    if (_isInterestedInUserInteracted) {
        for (id<CDInactivityNotifierListener> listener in _listenerSubscriptionTimes) {
            if ([listener respondsToSelector:@selector(userInteracted)]) {
                [listener userInteracted];
            }
        }
    }
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - Private internals
/////////////////////////////////////////////////////////////////////////

- (void)setup {
    
    /////////////////////////////////////////
    // Initialise vars
    /////////////////////////////////////////
    
    _timestampLastInteraction = -1;
    _shortestTimeoutDuration = -1;
    _lastNotifiedLongestDuration = -1;
    _isInterestedInUserInteracted = NO;
    
    if (_listenerSubscriptionTimes && _listenerSubscriptionTimes.count > 0) {
        // Recalculate shortest duration time
        for (id<CDInactivityNotifierListener> listener in _listenerSubscriptionTimes) {
            NSDictionary *dictTimes = [_listenerSubscriptionTimes objectForKey:listener];
            
            for (NSString *key in dictTimes) {
                NSArray *arrTimesForKey = [dictTimes objectForKey:key];
                
                for (NSNumber *time in arrTimesForKey) {
                    if (_shortestTimeoutDuration == -1 || time.floatValue < _shortestTimeoutDuration) {
                        _shortestTimeoutDuration = time.floatValue;
                    }
                }
            }
        }
        
        // Check if there is a listener interested in this callback
        for (id<CDInactivityNotifierListener> listener in _listenerSubscriptionTimes) {
            if ([listener respondsToSelector:@selector(userInteracted)]) {
                _isInterestedInUserInteracted = YES;
                break;
            }
        }
    }
    
    /////////////////////////////////////////
    // Listen to Application states
    /////////////////////////////////////////
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleGoingInactive)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:[UIApplication sharedApplication]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleGoingActive)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:[UIApplication sharedApplication]];
}

+ (CDInactivityNotifier *)sharedInstance {
    static CDInactivityNotifier *_instance;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [CDInactivityNotifier new];
    });
    
    return _instance;
}

- (void)activateTimeout {
    // Add a transparent view to inspect user interaction
    if (!_viewSticky) {
        _viewSticky = [CDStickyTransparentView new];
    }
    
    if (!_viewSticky.isAdded) {
        [_viewSticky add];
    }
    _viewSticky.interactionBegan = ^{
        _timestampLastInteraction = [self.class now];
        _lastNotifiedLongestDuration = -1;
        
        if (_isInterestedInUserInteracted) {
            for (id<CDInactivityNotifierListener> listener in _listenerSubscriptionTimes) {
                if ([listener respondsToSelector:@selector(userInteracted)]) {
                    [listener userInteracted];
                }
            }
        }
    };
    
    [_timerTimeout invalidate];
    _timestampLastInteraction = [self.class now];
    if (_shortestTimeoutDuration < 0) {
        return;
    }

    _timerTimeout = [NSTimer timerWithTimeInterval:_shortestTimeoutDuration/10. target:self selector:@selector(checkTimeout:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_timerTimeout forMode:NSRunLoopCommonModes];
}

- (void)checkTimeout:(NSTimer *)timer {
    dispatch_async(_q, ^{
        if (!timer.isValid) {
            return;
        }
        
        NSTimeInterval now = [self.class now];
        NSTimeInterval timePassed = now - _timestampLastInteraction;
        NSTimeInterval longestNotifiedThisIteration = -1;
        if (timePassed >= _shortestTimeoutDuration) {
            for (id<CDInactivityNotifierListener>listener in _listenerSubscriptionTimes) {
                NSDictionary *dictTimes = [_listenerSubscriptionTimes objectForKey:listener];
                for (NSString *key in dictTimes) {
                    NSString *keyToCallback = [key isEqualToString:kkCDStickyTransparentViewNilKey] ? nil : key;
                    NSArray *arrTimesForKey = [dictTimes objectForKey:key];
                    for (NSNumber *time in arrTimesForKey) {
                        NSTimeInterval duration = time.floatValue;
                        if (timePassed >= duration && duration > _lastNotifiedLongestDuration) {
                            [listener userDidNotInteractFor:timePassed key:keyToCallback];
                            longestNotifiedThisIteration = MAX(longestNotifiedThisIteration, duration);
                        }
                    }
                }
            }
        }
        _lastNotifiedLongestDuration = MAX(_lastNotifiedLongestDuration, longestNotifiedThisIteration);
    });
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - Application state notifications
/////////////////////////////////////////////////////////////////////////

- (void)handleGoingInactive {
    // Do nothing
}

- (void)handleGoingActive {
    // Reset
    _timestampLastInteraction = [self.class now];
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - Util methods
/////////////////////////////////////////////////////////////////////////

+ (NSTimeInterval)now {
    return CACurrentMediaTime();
}

@end
