//
//  MidiMonitorAppDelegate.m
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MidiMonitorAppDelegate.h"

#import "MidiMonitorViewController.h"
#import "MidiInput.h"
#import "iOSVersionDetection.h"

@implementation MidiMonitorAppDelegate

@synthesize window;
@synthesize viewController;

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];

    IF_IOS_HAS_COREMIDI
    (
        // We only create a MidiInput object on iOS versions that support CoreMIDI
        midiInput = [[MidiInput alloc] init];
        viewController.midiInput = midiInput;
    )

	return YES;
}



#pragma mark -
#pragma mark Memory management

- (void)dealloc
{
    [viewController release];
    [window release];
    [super dealloc];
}


@end
