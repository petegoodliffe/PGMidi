//
//  MidiMonitorViewController.m
//  MidiMonitor
//
//  Created by Pete Goodliffe on 10/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MidiMonitorViewController.h"

#import "PGMidi.h"
#import "iOSVersionDetection.h"
#import <CoreMIDI/CoreMIDI.h>

UInt8 RandomNoteNumber() { return rand() / (RAND_MAX / 127); }

@interface MidiMonitorViewController () <PGMidiDelegate>
- (void) updateCountLabel;
- (void) addString:(NSString*)string;
- (void) sendMidiDataInBackground;
@end

@implementation MidiMonitorViewController

#pragma mark PGMidiDelegate

@synthesize countLabel;
@synthesize textView;
@synthesize midi;

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

- (void) setMidi:(PGMidi*)m
{
    midi.delegate = nil;
    midi = m;
    midi.delegate = self;
}

- (void) addString:(NSString*)string
{
    NSString *newText = [textView.text stringByAppendingFormat:@"\n%@", string];
    textView.text = newText;

    if (newText.length)
        [textView scrollRangeToVisible:(NSRange){newText.length-1, 1}];
}

- (void) updateCountLabel
{
    countLabel.text = [NSString stringWithFormat:@"%u", midi.numberOfConnectedDevices];
}

- (void) midi:(PGMidi*)midi event:(NSString*)event
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

- (void) midi:(PGMidi*)midi midiReceived:(const MIDIPacketList *)packetList
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

        [midi sendMidi:noteOn size:sizeof(noteOn)];
        [NSThread sleepForTimeInterval:0.1];
        [midi sendMidi:noteOff size:sizeof(noteOff)];
    }
}

@end
