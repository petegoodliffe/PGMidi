//
//  PGMidi.m
//  PGMidi
//

#import "PGMidi.h"

#import "PGArc.h"

// For some reason, this is nut pulled in by the umbrella header
#import <CoreMIDI/MIDINetworkSession.h>

/// A helper that NSLogs an error message if "c" is an error code
#define NSLogError(c,str) do{if (c) NSLog(@"Error (%@): %ld:%@", str, (long)c,[NSError errorWithDomain:NSMachErrorDomain code:c userInfo:nil]);}while(false)

NSString * PGMidiSourceAddedNotification = @"PGMidiSourceAddedNotification";
NSString * PGMidiSourceRemovedNotification = @"PGMidiSourceRemovedNotification";
NSString * PGMidiDestinationAddedNotification = @"PGMidiDestinationAddedNotification";
NSString * PGMidiDestinationRemovedNotification = @"PGMidiDestinationRemovedNotification";

NSString * kPGMidiConnectionKey = @"connection";

//==============================================================================

static void PGMIDINotifyProc(const MIDINotification *message, void *refCon);
static void PGMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);

@interface PGMidi ()
- (void) scanExistingDevices;
- (MIDIPortRef) outputPort;
@end

//==============================================================================

static
NSString *NameOfEndpoint(MIDIEndpointRef ref)
{
    NSString *string = nil;
    OSStatus s = MIDIObjectGetStringProperty(ref, kMIDIPropertyDisplayName, (CFStringRef*)&string);
    if ( s != noErr ) 
    {
        string = @"Unknown name";
    }
    return string;
}

static
BOOL IsNetworkSession(MIDIEndpointRef ref)
{
    MIDIEntityRef entity = 0;
    MIDIEndpointGetEntity(ref, &entity);

    BOOL hasMidiRtpKey = NO;
    CFPropertyListRef properties = nil;
    OSStatus s = MIDIObjectGetProperties(entity, &properties, true);
    if (!s)
    {
        NSDictionary *dictionary = arc_cast<NSDictionary>(properties);
        hasMidiRtpKey = [dictionary valueForKey:@"apple.midirtp.session"] != nil;
        CFRelease(properties);
    }

    return hasMidiRtpKey;
}

//==============================================================================

@implementation PGMidiConnection

@synthesize midi;
@synthesize endpoint;
@synthesize name;
@synthesize isNetworkSession;

- (id) initWithMidi:(PGMidi*)m endpoint:(MIDIEndpointRef)e
{
    if ((self = [super init]))
    {
        midi                = m;
        endpoint            = e;
#if ! PGMIDI_ARC
        name                = [NameOfEndpoint(e) retain];
#else
        name                = NameOfEndpoint(e);
#endif
        isNetworkSession    = IsNetworkSession(e);
    }
    return self;
}

@end

//==============================================================================

@interface PGMidiSource ()
@property (strong, readwrite) NSArray *delegates;
@end

@implementation PGMidiSource

- (id) initWithMidi:(PGMidi*)m endpoint:(MIDIEndpointRef)e
{
    if ((self = [super initWithMidi:m endpoint:e]))
    {
        self.delegates = [NSArray array];
    }
    return self;
}

#if ! PGMIDI_ARC
- (void)dealloc 
{
    self.delegates = nil;
    [super dealloc];
}
#endif

- (void)addDelegate:(id<PGMidiSourceDelegate>)delegate {
    if ( [_delegates containsObject:[NSValue valueWithPointer:delegate]] ) return;
	self.delegates = [_delegates arrayByAddingObject:[NSValue valueWithPointer:delegate] /* avoid retain loop */];
}

- (void)removeDelegate:(id<PGMidiSourceDelegate>)delegate {
    NSMutableArray *mutableDelegates = [_delegates mutableCopy];
    [mutableDelegates removeObject:[NSValue valueWithPointer:delegate]];
    self.delegates = mutableDelegates;
}

// NOTE: Called on a separate high-priority thread, not the main runloop
- (void) midiRead:(const MIDIPacketList *)pktlist
{
    NSArray *delegates_ = self.delegates;
    for ( NSValue *delegatePtr in delegates_ ) 
    {
        id<PGMidiSourceDelegate> delegate = (id<PGMidiSourceDelegate>)[delegatePtr pointerValue];
        [delegate midiSource:self midiReceived:pktlist];
    }
}

static
void PGMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
    PGMidiSource *self = arc_cast<PGMidiSource>(srcConnRefCon);
    [self midiRead:pktlist];
}

@end

//==============================================================================

@implementation PGMidiDestination

- (id) initWithMidi:(PGMidi*)m endpoint:(MIDIEndpointRef)e
{
    if ((self = [super initWithMidi:m endpoint:e]))
    {
        midi     = m;
        endpoint = e;
    }
    return self;
}

- (void) sendBytes:(const UInt8*)bytes size:(UInt32)size
{
    NSLog(@"%s(%u bytes to core MIDI)", __func__, unsigned(size));
    assert(size < 65536);
    Byte packetBuffer[size+100];
    MIDIPacketList *packetList = (MIDIPacketList*)packetBuffer;
    MIDIPacket     *packet     = MIDIPacketListInit(packetList);
    packet = MIDIPacketListAdd(packetList, sizeof(packetBuffer), packet, 0, size, bytes);

    [self sendPacketList:packetList];
}

- (void) sendPacketList:(const MIDIPacketList *)packetList
{
    // Send it
    OSStatus s = MIDISend(midi.outputPort, endpoint, packetList);
    NSLogError(s, @"Sending MIDI");
}

@end

//==============================================================================

@implementation PGMidi

@synthesize delegate;
@synthesize sources,destinations;
@dynamic networkEnabled;

+ (BOOL)midiAvailable
{
    return [[[UIDevice currentDevice] systemVersion] floatValue] >= 4.2;
}

- (id) init
{
    if ((self = [super init]))
    {
        sources      = [NSMutableArray new];
        destinations = [NSMutableArray new];

        OSStatus s = MIDIClientCreate((CFStringRef)@"MidiMonitor MIDI Client", PGMIDINotifyProc, arc_cast<void>(self), &client);
        NSLogError(s, @"Create MIDI client");

        s = MIDIOutputPortCreate(client, (CFStringRef)@"MidiMonitor Output Port", &outputPort);
        NSLogError(s, @"Create output MIDI port");

        s = MIDIInputPortCreate(client, (CFStringRef)@"MidiMonitor Input Port", PGMIDIReadProc, arc_cast<void>(self), &inputPort);
        NSLogError(s, @"Create input MIDI port");

        [self scanExistingDevices];
    }

    return self;
}

- (void) dealloc
{
    if (outputPort)
    {
        OSStatus s = MIDIPortDispose(outputPort);
        NSLogError(s, @"Dispose MIDI port");
    }

    if (inputPort)
    {
        OSStatus s = MIDIPortDispose(inputPort);
        NSLogError(s, @"Dispose MIDI port");
    }

    if (client)
    {
        OSStatus s = MIDIClientDispose(client);
        NSLogError(s, @"Dispose MIDI client");
    }

#if ! PGMIDI_ARC
    [sources release];
    [destinations release];
    [super dealloc];
#endif
}

- (NSUInteger) numberOfConnections
{
    return sources.count + destinations.count;
}

- (MIDIPortRef) outputPort
{
    return outputPort;
}

-(BOOL)networkEnabled 
{
    return [MIDINetworkSession defaultSession].enabled;
}

-(void)setNetworkEnabled:(BOOL)networkEnabled 
{
    MIDINetworkSession* session = [MIDINetworkSession defaultSession];
    session.enabled = networkEnabled;
    session.connectionPolicy = MIDINetworkConnectionPolicy_Anyone;
}

//==============================================================================
#pragma mark Connect/disconnect

- (PGMidiSource*) getSource:(MIDIEndpointRef)source
{
    for (PGMidiSource *s in sources)
    {
        if (s.endpoint == source) return s;
    }
    return nil;
}

- (PGMidiDestination*) getDestination:(MIDIEndpointRef)destination
{
    for (PGMidiDestination *d in destinations)
    {
        if (d.endpoint == destination) return d;
    }
    return nil;
}

- (void) connectSource:(MIDIEndpointRef)endpoint
{
    PGMidiSource *source = [[PGMidiSource alloc] initWithMidi:self endpoint:endpoint];
    [sources addObject:source];
    [delegate midi:self sourceAdded:source];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiSourceAddedNotification
                                                        object:self 
                                                      userInfo:[NSDictionary dictionaryWithObject:source 
                                                                                           forKey:kPGMidiConnectionKey]];
    
    OSStatus s = MIDIPortConnectSource(inputPort, endpoint, arc_cast<void>(source));
    NSLogError(s, @"Connecting to MIDI source");
}

- (void) disconnectSource:(MIDIEndpointRef)endpoint
{
    PGMidiSource *source = [self getSource:endpoint];

    if (source)
    {
        OSStatus s = MIDIPortDisconnectSource(inputPort, endpoint);
        NSLogError(s, @"Disconnecting from MIDI source");
        [sources removeObject:source];
        
        [delegate midi:self sourceRemoved:source];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiSourceRemovedNotification
                                                            object:self 
                                                          userInfo:[NSDictionary dictionaryWithObject:source 
                                                                                               forKey:kPGMidiConnectionKey]];
        
#if ! PGMIDI_ARC
        [source release];
#endif
    }
}

- (void) connectDestination:(MIDIEndpointRef)endpoint
{
    PGMidiDestination *destination = [[PGMidiDestination alloc] initWithMidi:self endpoint:endpoint];
    [destinations addObject:destination];
    [delegate midi:self destinationAdded:destination];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiDestinationAddedNotification
                                                        object:self 
                                                      userInfo:[NSDictionary dictionaryWithObject:destination 
                                                                                           forKey:kPGMidiConnectionKey]];

}

- (void) disconnectDestination:(MIDIEndpointRef)endpoint
{
    PGMidiDestination *destination = [self getDestination:endpoint];

    if (destination)
    {
        [destinations removeObject:destination];
        
        [delegate midi:self destinationRemoved:destination];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PGMidiDestinationRemovedNotification
                                                            object:self 
                                                          userInfo:[NSDictionary dictionaryWithObject:destination 
                                                                                               forKey:kPGMidiConnectionKey]];

#if ! PGMIDI_ARC
        [destination release];
#endif
    }
}

- (void) scanExistingDevices
{
    const ItemCount numberOfDestinations = MIDIGetNumberOfDestinations();
    const ItemCount numberOfSources      = MIDIGetNumberOfSources();

    for (ItemCount index = 0; index < numberOfDestinations; ++index)
        [self connectDestination:MIDIGetDestination(index)];
    for (ItemCount index = 0; index < numberOfSources; ++index)
        [self connectSource:MIDIGetSource(index)];
}

//==============================================================================
#pragma mark Notifications

- (void) midiNotifyAdd:(const MIDIObjectAddRemoveNotification *)notification
{
    if (notification->childType == kMIDIObjectType_Destination)
        [self connectDestination:(MIDIEndpointRef)notification->child];
    else if (notification->childType == kMIDIObjectType_Source)
        [self connectSource:(MIDIEndpointRef)notification->child];
}

- (void) midiNotifyRemove:(const MIDIObjectAddRemoveNotification *)notification
{
    if (notification->childType == kMIDIObjectType_Destination)
        [self disconnectDestination:(MIDIEndpointRef)notification->child];
    else if (notification->childType == kMIDIObjectType_Source)
        [self disconnectSource:(MIDIEndpointRef)notification->child];
}

- (void) midiNotify:(const MIDINotification*)notification
{
    switch (notification->messageID)
    {
        case kMIDIMsgObjectAdded:
            [self midiNotifyAdd:(const MIDIObjectAddRemoveNotification *)notification];
            break;
        case kMIDIMsgObjectRemoved:
            [self midiNotifyRemove:(const MIDIObjectAddRemoveNotification *)notification];
            break;
        case kMIDIMsgSetupChanged:
        case kMIDIMsgPropertyChanged:
        case kMIDIMsgThruConnectionsChanged:
        case kMIDIMsgSerialPortOwnerChanged:
        case kMIDIMsgIOError:
            break;
    }
}

void PGMIDINotifyProc(const MIDINotification *message, void *refCon)
{
    PGMidi *self = arc_cast<PGMidi>(refCon);
    [self midiNotify:message];
}

//==============================================================================
#pragma mark MIDI Output

- (void) sendPacketList:(const MIDIPacketList *)packetList
{
    for (ItemCount index = 0; index < MIDIGetNumberOfDestinations(); ++index)
    {
        MIDIEndpointRef outputEndpoint = MIDIGetDestination(index);
        if (outputEndpoint)
        {
            // Send it
            OSStatus s = MIDISend(outputPort, outputEndpoint, packetList);
            NSLogError(s, @"Sending MIDI");
        }
    }
}

- (void) sendBytes:(const UInt8*)data size:(UInt32)size
{
    NSLog(@"%s(%u bytes to core MIDI)", __func__, unsigned(size));
    assert(size < 65536);
    Byte packetBuffer[size+100];
    MIDIPacketList *packetList = (MIDIPacketList*)packetBuffer;
    MIDIPacket     *packet     = MIDIPacketListInit(packetList);

    packet = MIDIPacketListAdd(packetList, sizeof(packetBuffer), packet, 0, size, data);

    [self sendPacketList:packetList];
}

@end
