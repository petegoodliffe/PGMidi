//
//  MidiMonitorViewController.m
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MidiMonitorViewController.h"

#import "MidiInput.h"
#import "iOSVersionDetection.h"
#import <CoreMIDI/CoreMIDI.h>

UInt8 RandomNoteNumber() { return rand() / (RAND_MAX / 127); }

@interface MidiMonitorViewController () <MidiInputDelegate>
- (void) updateCountLabel;
- (void) addString:(NSString*)string;
- (void) sendMidiDataInBackground;
@end

@implementation MidiMonitorViewController

#pragma mark MidiInputDelegate

@synthesize countLabel;
@synthesize textView;
@synthesize midiInput;

#pragma mark UIViewController

- (void) viewWillAppear:(BOOL)animated
{
    [self clearTextView];
    [self updateCountLabel];

    IF_IOS_HAS_COREMIDI
    (
         [self addString:@"This iOS Version supports CoreMIDI"];
    )
    else
    {
        [self addString:@"You are running iOS before 4.2. CoreMIDI is not supported."];
    }
}

#pragma mark IBActions

- (IBAction) clearTextView
{
    textView.text = nil;
}

- (IBAction) listAllInterfaces
{
    IF_IOS_HAS_COREMIDI
    (
        ListInterfaces(self);
    )
}

- (IBAction) sendMidiData
{
    [self performSelectorInBackground:@selector(sendMidiDataInBackground) withObject:nil];
}

#pragma mark Shenanigans

- (void) setMidiInput:(MidiInput*)mi
{
    midiInput.delegate = nil;
    midiInput = mi;
    midiInput.delegate = self;
}

- (void) addString:(NSString*)string
{
    textView.text = [textView.text stringByAppendingFormat:@"\n%@", string];
}

- (void) updateCountLabel
{
    countLabel.text = [NSString stringWithFormat:@"%u", midiInput.numberOfConnectedDevices];
}

- (void) midiInput:(MidiInput*)input event:(NSString*)event
{
    [self updateCountLabel];
    [self addString:event];
}

NSString *StringFromPacket(const MIDIPacket *packet)
{
    return [NSString stringWithFormat:@"  %u bytes: [%02x,%02x,%02x]",
            packet->length,
            (packet->length > 0) ? packet->data[0] : 0,
            (packet->length > 1) ? packet->data[1] : 0,
            (packet->length > 2) ? packet->data[2] : 0
           ];
}

- (void) midiInput:(MidiInput*)input midiReceived:(const MIDIPacketList *)packetList
{
    [self performSelectorOnMainThread:@selector(addString:)
                           withObject:@"MIDI received:"
                        waitUntilDone:NO];

    const MIDIPacket *packet = &packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; ++i)
    {
        [self performSelectorOnMainThread:@selector(addString:)
                               withObject:StringFromPacket(packet)
                            waitUntilDone:NO];
        packet = MIDIPacketNext(packet);
    }
}

- (void) sendMidiDataInBackground
{
    for (int n = 0; n < 20; ++n)
    {
        const UInt8 note      = RandomNoteNumber();
        const UInt8 noteOn[]  = { 0x90, note, 127 };
        const UInt8 noteOff[] = { 0x80, note, 0   };

        [midiInput sendMidi:noteOn size:sizeof(noteOn)];
        [NSThread sleepForTimeInterval:0.1];
        [midiInput sendMidi:noteOff size:sizeof(noteOff)];
    }
}

@end
