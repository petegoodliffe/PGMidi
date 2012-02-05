//
//  PGMidiAllSources.h
//  PGMidi
//

#import <Foundation/Foundation.h>

@class PGMidi;
@protocol PGMidiSourceDelegate;

@interface PGMidiAllSources : NSObject
{
    PGMidi                  *midi;
    id<PGMidiSourceDelegate> delegate;
}

@property (nonatomic,assign) PGMidi *midi;
@property (nonatomic,assign) id<PGMidiSourceDelegate> delegate;

@end
