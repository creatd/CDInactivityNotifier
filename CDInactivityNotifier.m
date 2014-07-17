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

/////////////////////////////////////////////////////////////////////////
#pragma mark - Public methods
/////////////////////////////////////////////////////////////////////////

- (void)add {
    if (self.isAdded) {
        NSLog(@"Warning - Won't add transparent view, it's already added");
        return;
    }
    
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(remove) withObject:nil waitUntilDone:NO];
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
    NSMapTable *_listenerSubscriptionTimes; // Mapping listener objects to array of durations
    NSTimeInterval _lastNotifiedLongestDuration; // Longest subscribed duration that was notified in the last notification iteration

    // Flags
    BOOL _isInterestedInUserInteracted; // YES if there is at least one listener interested in userInteracted callback method (for performance reasons)
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
    [self setup];
}

+ (void)subscribeListener:(id<CDInactivityNotifierListener, NSCoding>)listener forDuration:(NSTimeInterval)duration {
    if (duration < 1) {
        NSLog(@"Error - Cannot add listener for less than 1 second (%f)",duration);
        return;
    }
    else if (![listener conformsToProtocol:@protocol(CDInactivityNotifierListener)]) {
        NSLog(@"Error - Listener does not conform to CDInactivityNotifierListener protocol");
        return;
    }
    return [[self sharedInstance] subscribeListener:listener forDuration:duration];
}

- (void)subscribeListener:(id<CDInactivityNotifierListener, NSCoding>)listener forDuration:(NSTimeInterval)duration {
    if (!_listenerSubscriptionTimes) {
        _listenerSubscriptionTimes = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory];
    }
    
    if (_shortestTimeoutDuration < 0 || duration < _shortestTimeoutDuration) {
        _shortestTimeoutDuration = duration;
        [self activateTimeout];
    }
    
    NSArray *arrTimes = [_listenerSubscriptionTimes objectForKey:listener];
    if (arrTimes) {
        NSMutableArray *arrNewTimes = [NSMutableArray arrayWithArray:arrTimes];
        [arrNewTimes addObject:[NSNumber numberWithFloat:duration]];
        [_listenerSubscriptionTimes setObject:arrNewTimes forKey:listener];
    }
    else {
        [_listenerSubscriptionTimes setObject:@[[NSNumber numberWithFloat:duration]] forKey:listener];
    }
    
    if (!_isInterestedInUserInteracted && [listener respondsToSelector:@selector(userInteracted)]) {
        _isInterestedInUserInteracted = YES;
    }
}

+ (void)unsubscribeListener:(id<CDInactivityNotifierListener,NSCoding>)listener {

    return [[self sharedInstance] unsubscribeListener:listener];
}

- (void)unsubscribeListener:(id<CDInactivityNotifierListener,NSCoding>)listener {
    
    [_listenerSubscriptionTimes removeObjectForKey:listener];
    
    // Recalculate shortest duration time
    NSTimeInterval shortestDuration = -1;
    for (id<CDInactivityNotifierListener> otherListener in _listenerSubscriptionTimes) {
        NSArray *arrTimes = [_listenerSubscriptionTimes objectForKey:otherListener];
        for (NSNumber *time in arrTimes) {
            if (shortestDuration == -1 || time.floatValue < shortestDuration) {
                shortestDuration = time.floatValue;
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
}

+ (void)deactivate {
    [[CDInactivityNotifier sharedInstance] deactivate];
}

- (void)deactivate {
    [_timerTimeout invalidate];
    _timerTimeout = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (void)disableFor:(NSTimeInterval)duration {
    [[CDInactivityNotifier sharedInstance] disableFor:duration];
}

- (void)disableFor:(NSTimeInterval)duration {
    _timestampLastInteraction = [self.class now] + duration;
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - Private internals
/////////////////////////////////////////////////////////////////////////

- (void)setup {
    
    /////////////////////////////////////////
    // Reset vars
    /////////////////////////////////////////
    
    _timestampLastInteraction = -1;
    _shortestTimeoutDuration = -1;
    _lastNotifiedLongestDuration = -1;
    _isInterestedInUserInteracted = NO;
    
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

- (void)cancelTimeout {
    [_timerTimeout invalidate];
    [_viewSticky remove];
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
    _timerTimeout = [NSTimer scheduledTimerWithTimeInterval:_shortestTimeoutDuration/10. target:self selector:@selector(checkTimeout:) userInfo:nil repeats:YES];
}

- (void)checkTimeout:(NSTimer *)timer {
    if (!timer.isValid) {
        return;
    }
    
    NSTimeInterval now = [self.class now];
    NSTimeInterval timePassed = now - _timestampLastInteraction;
    NSTimeInterval longestNotifiedThisIteration = -1;
    if (timePassed >= _shortestTimeoutDuration) {
        for (id<CDInactivityNotifierListener>listener in _listenerSubscriptionTimes) {
            NSArray *arrTimes = [_listenerSubscriptionTimes objectForKey:listener];
            for (NSNumber *time in arrTimes) {
                NSTimeInterval duration = time.floatValue;
                if (timePassed >= duration && duration > _lastNotifiedLongestDuration) {
                    [listener userDidNotInteractFor:timePassed];
                    longestNotifiedThisIteration = MAX(longestNotifiedThisIteration, duration);
                }
            }
        }
    }
    _lastNotifiedLongestDuration = MAX(_lastNotifiedLongestDuration, longestNotifiedThisIteration);
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
