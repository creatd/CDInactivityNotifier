//
//  CDMainVC.m
//  CDInactivityNotifierDemo
//
//  Created by Ismail Ege AKPINAR on 17/07/2014.
//  Copyright (c) 2014 Creatd. All rights reserved.
//

#import "CDMainVC.h"

// Etc
#import "CDInactivityNotifier.h"

@interface CDMainVC ()<CDInactivityNotifierListener>

// UI elements
@property (weak, nonatomic) IBOutlet UIView *viewGreen1;
@property (weak, nonatomic) IBOutlet UIView *viewGreen2;
@property (weak, nonatomic) IBOutlet UIView *viewGreen3;
@property (weak, nonatomic) IBOutlet UIView *viewGreen4;
@property (weak, nonatomic) IBOutlet UIView *viewGreen5;
@property (weak, nonatomic) IBOutlet UIView *viewGreen6;
@property (weak, nonatomic) IBOutlet UIView *viewGreen7;
@property (weak, nonatomic) IBOutlet UIView *viewGreen8;


@end

@implementation CDMainVC

/////////////////////////////////////////////////////////////////////////
#pragma mark - CDInactivityNotifierListener methods
/////////////////////////////////////////////////////////////////////////

- (void)userDidNotInteractFor:(NSTimeInterval)duration key:(NSString *)key {
    NSLog(@"inactivity for %f key %@",duration, key);
    
    void(^block)() = ^{
        if (duration >= 2) {
            self.viewGreen1.hidden = NO;
            if (duration >= 4) {
                self.viewGreen2.hidden = NO;
                if (duration >= 8) {
                    self.viewGreen3.hidden = NO;
                }
            }
        }
        
        if ([key isEqualToString:@"A"]) {
            self.viewGreen4.hidden = NO;
            [CDInactivityNotifier unsubscribeListener:self withKey:@"A"]; // Testing
        }
        else if ([key isEqualToString:@"B"]) {
            self.viewGreen5.hidden = NO;
        }
        else if ([key isEqualToString:@"C"]) {
            self.viewGreen6.hidden = NO;
        }
        else if ([key isEqualToString:@"D"]) {
            self.viewGreen7.hidden = NO;
        }
        else if ([key isEqualToString:@"E"]) {
            self.viewGreen8.hidden = NO;
        }
    };
    
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), block);
    }
    else {
        block();
    }
}

- (void)userInteracted {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(userInteracted) withObject:nil waitUntilDone:NO];
        return;
    }
    
    self.viewGreen1.hidden = YES;
    self.viewGreen2.hidden = YES;
    self.viewGreen3.hidden = YES;
    self.viewGreen4.hidden = YES;
    self.viewGreen5.hidden = YES;
    self.viewGreen6.hidden = YES;
    self.viewGreen7.hidden = YES;
    self.viewGreen8.hidden = YES;
}

/////////////////////////////////////////////////////////////////////////
#pragma mark - View lifecycle
/////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [CDInactivityNotifier activate];
    
    [CDInactivityNotifier subscribeListener:self forDuration:2 withKey:nil];
    [CDInactivityNotifier subscribeListener:self forDuration:4 withKey:nil];
    [CDInactivityNotifier subscribeListener:self forDuration:8 withKey:nil];
    [CDInactivityNotifier subscribeListener:self forDuration:16 withKey:@"A"];
    [CDInactivityNotifier subscribeListener:self forDuration:32 withKey:@"B"];
    [CDInactivityNotifier subscribeListener:self forDuration:64 withKey:@"C"];
    [CDInactivityNotifier subscribeListener:self forDuration:100 withKey:@"D"];
    [CDInactivityNotifier subscribeListener:self forDuration:300 withKey:@"E"];
    
    // Uncomment below to see unsubscribe in action
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10. * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [CDInactivityNotifier unsubscribeListener:self];
//    });
}

- (id)init {
    if (self = [super initWithNibName:@"CDMainView" bundle:nil]) {
        
    }
    return self;
}

@end
