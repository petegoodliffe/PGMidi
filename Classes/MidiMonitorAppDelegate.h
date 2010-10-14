//
//  MidiMonitorAppDelegate.h
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MidiMonitorViewController;

@interface MidiMonitorAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    MidiMonitorViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet MidiMonitorViewController *viewController;

@end

