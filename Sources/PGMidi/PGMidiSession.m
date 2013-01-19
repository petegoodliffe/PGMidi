//
//  PGMidiSession.m
//  PGMidi
//
//  Created by Dan Hassin on 1/19/13.
//
//

#import "PGMidiSession.h"

#include <mach/mach.h>
#include <mach/mach_time.h>

uint64_t convertTimeInNanoseconds(uint64_t time)
{
    const int64_t kOneThousand = 1000;
    static mach_timebase_info_data_t s_timebase_info;
	
    if (s_timebase_info.denom == 0)
    {
        (void) mach_timebase_info(&s_timebase_info);
    }
	
    // mach_absolute_time() returns billionth of seconds,
    // so divide by one thousand to get nanoseconds
    return (uint64_t)((time * s_timebase_info.numer) / (kOneThousand * s_timebase_info.denom));
}

@implementation PGMidiSession
{
	double currentClockTime;
	double previousClockTime;
}

@synthesize midi, delegate, bpm;

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

/* Taken from http://stackoverflow.com/questions/13562714/calculate-accurate-bpm-from-midi-clock-in-objc-with-coremidi */
- (void) midiSource:(PGMidiSource*)input midiReceived:(const MIDIPacketList *)packetList
{
	MIDIPacket *packet = (MIDIPacket*)&packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; ++i)
    {
        int statusByte = packet->data[0];
        int status = statusByte >= 0xf0 ? statusByte : statusByte & 0xF0;
		
        if(status == VVMIDIClockVal)
        {
            previousClockTime = currentClockTime;
            currentClockTime = packet->timeStamp;
			
            if(previousClockTime > 0 && currentClockTime > 0)
            {
                double intervalInNanoseconds = convertTimeInNanoseconds(currentClockTime-previousClockTime);
                bpm = (1000000 / intervalInNanoseconds / 24) * 60;
            }
        }
		
        packet = MIDIPacketNext(packet);
    }
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

@end
