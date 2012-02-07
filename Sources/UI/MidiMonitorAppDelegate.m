//
//  MidiMonitorAppDelegate.m
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MidiMonitorAppDelegate.h"

#import "MidiMonitorViewController.h"
#import "PGMidi.h"
#import "iOSVersionDetection.h"
#import "PGArc.h"

@implementation MidiMonitorAppDelegate

@synthesize window;
@synthesize viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];

    IF_IOS_HAS_COREMIDI
    (
        // We only create a MidiInput object on iOS versions that support CoreMIDI
        midi = [[PGMidi alloc] init];
        [midi enableNetwork:YES];
        viewController.midi = midi;
    )

	return YES;
}

- (void)dealloc
{
#if ! PGMIDI_ARC
    [viewController release];
    [window release];
    [super dealloc];
#endif
}

@end
