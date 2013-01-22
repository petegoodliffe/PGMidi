//
//  PGMidiSession.m
//  PGMidi
//
//  Created by Dan Hassin on 1/19/13.
//
//

#import "PGMidiSession.h"

@interface QuantizedBlock : NSObject

@property (copy) void(^block)();
@property (nonatomic) double interval;
@property (nonatomic) int extraBars;

@end

@implementation QuantizedBlock
@synthesize block, interval, extraBars;

@end


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
	
	int num96notes;
	
	NSMutableArray *quantizedBlockQueue;
}

@synthesize midi, delegate, bpm, playing;

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
		quantizedBlockQueue = [[NSMutableArray alloc] init];
		
		midi = [[PGMidi alloc] init];
		midi.automaticSourceDelegate = self;
        [midi enableNetwork:YES];
		
		bpm = -1; //signifies no MIDI clock in
	}
	return self;
}

- (void) performBlock:(void (^)(void))block quantizedToNumberOfBars:(double)bars
{
	QuantizedBlock *qb = [[QuantizedBlock alloc] init];
	qb.block = block;
	qb.extraBars = (int)bars; //truncate to a whole number
	qb.interval =  bars-qb.extraBars; //get the decimal part
	if (qb.interval == 0)
		qb.interval = 1; //if the interval is on a 1 downbeat it'll be 0
	NSLog(@"after %d bars, will run at the %d (currently on %d)",qb.extraBars,(int)(qb.interval*96),num96notes);
	[quantizedBlockQueue addObject:qb];
}

- (void) midiSource:(PGMidiSource *)source midiReceived:(const MIDIPacketList *)packetList
{
	MIDIPacket *packet = (MIDIPacket*)&packetList->packet[0];
    for (int i = 0; i < packetList->numPackets; ++i)
    {
		Byte *data = packet->data;
        int statusByte = data[0];
        int status = statusByte >= 0xf0 ? statusByte : statusByte & 0xF0;
		
        if (status == VVMIDIClockVal)
        {
			if (playing)
			{
				/* every MIDI clock packet sent is a 96th note. */
				/* 0 is the downbeat of 1 */
				if (num96notes == 0)
				{
					for (QuantizedBlock *qb in quantizedBlockQueue)
					{
						qb.extraBars--;
					}
					NSLog(@"tick");
				}
				
				for (int i = 0; i < quantizedBlockQueue.count; i++)
				{
					QuantizedBlock *qb = quantizedBlockQueue[i];
					int interval = (int)(qb.interval*96);
					if (num96notes % interval == 0 && qb.extraBars <= 0)
					{
						//run the block on the main thread to allow UI updates etc
						dispatch_async(dispatch_get_main_queue(), qb.block);
						[quantizedBlockQueue removeObjectAtIndex:i];
						i--;
					}
				}

				num96notes = (num96notes + 1) % 96;
			}
			
			/* BPM calculation taken from http://stackoverflow.com/questions/13562714/calculate-accurate-bpm-from-midi-clock-in-objc-with-coremidi */

            previousClockTime = currentClockTime;
            currentClockTime = packet->timeStamp;
			
            if(previousClockTime > 0 && currentClockTime > 0)
            {
                double intervalInNanoseconds = convertTimeInNanoseconds(currentClockTime-previousClockTime);
                bpm = (1000000 / intervalInNanoseconds / 24) * 60;
            }
        }
		else if (status == VVMIDINoteOnVal)
		{
			dispatch_async(dispatch_get_main_queue(), ^
						   {
							   [delegate midiSource:source sentNote:data[1] velocity:data[2]];
						   });
		}
		else if (status == VVMIDIControlChangeVal)
		{
			dispatch_async(dispatch_get_main_queue(), ^
						   {
							   [delegate midiSource:source sentCC:data[1] value:data[2]];
						   });
		}
		else if (status == VVMIDIStartVal)
		{
			playing = YES;
			//reset to 0 -- the immediate next MIDI clock signal will be the downbeat of 1
			num96notes = 0;
		}
		else if (status == VVMIDIStopVal)
		{
			playing = NO;
		}
		
        packet = MIDIPacketNext(packet);
    }
}

- (void) sendCC:(int)cc value:(int)val
{
	const UInt8 cntrl[]  = { VVMIDIControlChangeVal, cc, val };
	[midi sendBytes:cntrl size:sizeof(cntrl)];
}

- (void) sendNote:(int)note
{
	[self sendNote:note velocity:127 length:0];
}

- (void) sendNote:(int)note velocity:(int)vel length:(NSTimeInterval)length
{
	const UInt8 noteOn[]  = { VVMIDINoteOnVal, note, vel };
	[midi sendBytes:noteOn size:sizeof(noteOn)];

	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, length * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
	{
		const UInt8 noteOff[]  = { VVMIDINoteOffVal, note, vel };
		[midi sendBytes:noteOff size:sizeof(noteOn)];
	});
}

@end
