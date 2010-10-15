//
//  MidiMonitorAppDelegate.h
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MidiMonitorViewController;
@class MidiInput;

@interface MidiMonitorAppDelegate : NSObject <UIApplicationDelegate>
{
    UIWindow                  *window;
    MidiMonitorViewController *viewController;
    MidiInput                 *midiInput;
}

@property (nonatomic, retain) IBOutlet UIWindow                  *window;
@property (nonatomic, retain) IBOutlet MidiMonitorViewController *viewController;

@end

