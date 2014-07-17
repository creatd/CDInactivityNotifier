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

- (void)userDidNotInteractFor:(NSTimeInterval)duration {
    NSLog(@"inactivity for %f",duration);
    
    if (duration >= 2) {
        self.viewGreen1.hidden = NO;
        if (duration >= 4) {
            self.viewGreen2.hidden = NO;
            if (duration >= 8) {
                self.viewGreen3.hidden = NO;
                if (duration >= 16) {
                    self.viewGreen4.hidden = NO;
                    if (duration >= 32) {
                        self.viewGreen5.hidden = NO;
                        if (duration >= 64) {
                            self.viewGreen6.hidden = NO;
                            if (duration >= 100) {
                                self.viewGreen7.hidden = NO;
                                if (duration >= 300) {
                                    self.viewGreen8.hidden = NO;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

- (void)userInteracted {
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
    
    [CDInactivityNotifier subscribeListener:self forDuration:2];
    [CDInactivityNotifier subscribeListener:self forDuration:4];
    [CDInactivityNotifier subscribeListener:self forDuration:8];
    [CDInactivityNotifier subscribeListener:self forDuration:16];
    [CDInactivityNotifier subscribeListener:self forDuration:32];
    [CDInactivityNotifier subscribeListener:self forDuration:64];
    [CDInactivityNotifier subscribeListener:self forDuration:100];
    [CDInactivityNotifier subscribeListener:self forDuration:300];
    
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
