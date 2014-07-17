//
//  CDAppDelegate.m
//  CDInactivityNotifierDemo
//
//  Created by Ismail Ege AKPINAR on 17/07/2014.
//  Copyright (c) 2014 Creatd. All rights reserved.
//

#import "CDAppDelegate.h"

// VC
#import "CDMainVC.h"

@implementation CDAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    
    self.window.rootViewController = [CDMainVC new];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

@end
