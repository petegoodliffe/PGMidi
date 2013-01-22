//
//  PGMidiSession.h
//  PGMidi
//
//  Created by Dan Hassin on 1/19/13.
//
//

#import <Foundation/Foundation.h>
#import "PGMidi.h"

/*
 PGMidiSession is an addition to PGMidi specifically designed for use with a DAW.
 
 How do I use this class?
 It's simple, and requires no client-side setup! You can go right into these (although setting a delegate first thing is preferred to instantiate the singleton and give it time to connect to MIDI sources/destinations).
 
 Sending a note/CC:
	 [[PGMidiSession sharedSession] sendNote:36];
	 [[PGMidiSession sharedSession] sendNote:36 velocity:120 length:1];
	 [[PGMidiSession sharedSession] sendCC:5 value:127];
 
 Accessing BPM:
	 [PGMidiSession sharedSession].bpm
 
 Receiving MIDI data:
	 Set [PGMidiSession sharedSession].delegate to a PGMidiSourceDelegate and implement the two delegate methods!
 
 Quantization (the main reason I wrote this class):
	 [[PGMidiSession sharedSession] performBlock:^{ NSLog(@"HI"); } quantizedToInterval:1];    // Prints "HI" on the next downbeat of a new bar
	 [[PGMidiSession sharedSession] performBlock:^{ NSLog(@"HI"); } quantizedToInterval:0.25]; // Prints "HI" on the next quarter note
	 [[PGMidiSession sharedSession] performBlock:^{ NSLog(@"HI"); } quantizedToInterval:1.25]; // Waits till the next bar, then prints "HI" on the next quarter note
 
 
 Troubleshooting:
 
 For quantization and BPM to work, the iOS device must be receiving a MIDI clock signal. For quantization, the iOS device has to "see" a MIDI START signal (ie, in a DAW, the play button). It won't work if it's already playing when the device connects.
 
 If you're having trouble setting this whole thing up, remember you can connect your device via network session in Audio MIDI Setup.app, under Network in the MIDI window.
 */

@protocol PGMidiSessionDelegate;

@interface PGMidiSession : NSObject <PGMidiSourceDelegate>

@property (nonatomic, PGMIDI_DELEGATE_PROPERTY) id<PGMidiSessionDelegate> delegate;
@property (nonatomic, strong) PGMidi *midi;
@property (nonatomic) double bpm;
@property (nonatomic, getter = isPlaying) BOOL playing;

+ (PGMidiSession *) sharedSession;

/* See above for usage. Simple enough */
- (void) sendCC:(int)cc value:(int)val;
- (void) sendNote:(int)note;
- (void) sendNote:(int)cc velocity:(int)vel length:(NSTimeInterval)length;
- (void) performBlock:(void (^)(void))block quantizedToInterval:(double)numBarsOrFraction;

@end

@protocol PGMidiSessionDelegate <NSObject>

- (void) midiSource:(PGMidiSource *)source sentNote:(int)note velocity:(int)vel;
- (void) midiSource:(PGMidiSource *)source sentCC:(int)cc value:(int)val;

@end
