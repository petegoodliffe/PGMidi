//
//  MidiMonitorViewController.m
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MidiMonitorViewController.h"

#import "MidiInput.h"

@interface MidiMonitorViewController () <MidiInputDelegate>
@end

@implementation MidiMonitorViewController

#pragma mark MidiInputDelegate

@synthesize countLabel;
@synthesize textView;
@synthesize midiInput;

- (void) setMidiInput:(MidiInput*)mi
{
    midiInput.delegate = nil;
    midiInput = mi;
    midiInput.delegate = self;
}

- (void) midiInput:(MidiInput*)input event:(NSString*)event
{
}

- (void) midiInput:(MidiInput*)input midiReceived:(const MIDIPacketList *)packetList
{
}

@end
