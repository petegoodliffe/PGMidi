//
//  MidiInput.h
//  iDJ-Pro
//
//  Created by Pete Goodliffe on 10/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMIDI/CoreMIDI.h>

@class MidiInput;

/// Delegate protocol for MidiInput class.
/// Adopt this protocol in your object to receive events from MIDI
@protocol MidiInputDelegate
- (void) midiInput:(MidiInput*)input event:(NSString*)event;
- (void) midiInput:(MidiInput*)input midiReceived:(const MIDIPacketList *)packetList;
@end

/// Class for receiving MIDI input from any MIDI device.
///
/// If you intend your app to support iOS 3.x which does not have CoreMIDI
/// support, weak link to the CoreMIDI framework, and only create a
/// MidiInput object if you are running the right version of iOS.
@interface MidiInput : NSObject
{
    MIDIClientRef           client;
    MIDIPortRef             outputPort;
    MIDIPortRef             inputPort;
    id<MidiInputDelegate>   delegate;
}

@property (nonatomic,assign) id<MidiInputDelegate> delegate;

@end

NSUInteger ListInterfaces();
