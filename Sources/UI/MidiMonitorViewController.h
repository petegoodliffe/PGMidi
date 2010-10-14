//
//  MidiMonitorViewController.h
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MidiInput;

@interface MidiMonitorViewController : UIViewController
{
    UILabel    *countLabel;
    UITextView *textView;

    MidiInput *midiInput;
}

@property (nonatomic,retain) IBOutlet UILabel    *countLabel;
@property (nonatomic,retain) IBOutlet UITextView *textView;

@property (nonatomic,assign) MidiInput *midiInput;


@end

