//
//  PGMidiSession.m
//  PGMidi
//
//  Created by Dan Hassin on 1/19/13.
//
//

#import "PGMidiSession.h"

@implementation PGMidiSession
{
}

@synthesize midi, delegate;

static PGMidiSession *shared = nil;

+ (PGMidiSession *) sharedSession
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [[PGMidiSession alloc] init];
	});
	
	return shared;
}

- (id) init
{
	self = [super init];
	if (self)
	{
		midi = [[PGMidi alloc] init];
		midi.automaticSourceDelegate = self;
        [midi enableNetwork:YES];
	}
	return self;
}

- (void) sendCC:(int)cc value:(int)val
{
	const UInt8 cntrl[]  = { VVMIDIControlChangeVal, cc, val };
	[midi sendBytes:cntrl size:sizeof(cntrl)];
}

- (void) sendNote:(int)note velocity:(int)vel
{
	const UInt8 noteOn[]  = { VVMIDINoteOnVal, note, vel };
	[midi sendBytes:noteOn size:sizeof(noteOn)];
}


- (void) midiSource:(PGMidiSource *)input midiReceived:(const MIDIPacketList *)packetList
{
	NSLog(@"received MIDI");
}

@end
