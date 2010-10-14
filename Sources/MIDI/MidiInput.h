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
///
/// IMPORTANT NOTE:
/// MIDI input is received from a high prirotiy background thread
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
    NSUInteger              numberOfConnectedDevices;
    id<MidiInputDelegate>   delegate;
}

@property (nonatomic,assign)   id<MidiInputDelegate> delegate;
@property (nonatomic,readonly) NSUInteger            numberOfConnectedDevices;

@end

/// Dump a list of MIDI interfaces as events on this delegate.
///
/// A helpful diagnostic, and an example of how to enumerate devices
NSUInteger ListInterfaces(id<MidiInputDelegate> delegate);
