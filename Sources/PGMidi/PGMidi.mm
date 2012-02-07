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

//==============================================================================
// ARC


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

    MIDIEntityRef entity = 0;
    MIDIEndpointGetEntity(ref, &entity);

    CFPropertyListRef properties = nil;
    OSStatus s = MIDIObjectGetProperties(entity, &properties, true);
    if (s)
    {
        string = @"Unknown name";
    }
    else
    {
        //NSLog(@"Properties = %@", properties);
        NSDictionary *dictionary = arc_cast<NSDictionary>(properties);
        string = [NSString stringWithFormat:@"%@", [dictionary valueForKey:@"name"]];
        CFRelease(properties);
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

@implementation PGMidiSource

@synthesize delegate;

- (id) initWithMidi:(PGMidi*)m endpoint:(MIDIEndpointRef)e
{
    if ((self = [super initWithMidi:m endpoint:e]))
    {
    }
    return self;
}

// NOTE: Called on a separate high-priority thread, not the main runloop
- (void) midiRead:(const MIDIPacketList *)pktlist
{
    [delegate midiSource:self midiReceived:pktlist];
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

- (void) enableNetwork:(BOOL)enabled
{
    MIDINetworkSession* session = [MIDINetworkSession defaultSession];
    session.enabled = YES;
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

        [delegate midi:self sourceRemoved:source];

        [sources removeObject:source];
#if ! PGMIDI_ARC
        [source release];
#endif
    }
}

- (void) connectDestination:(MIDIEndpointRef)endpoint
{
    //[delegate midiInput:self event:@"Added a destination"];
    PGMidiDestination *destination = [[PGMidiDestination alloc] initWithMidi:self endpoint:endpoint];
    [destinations addObject:destination];
    [delegate midi:self destinationAdded:destination];
}

- (void) disconnectDestination:(MIDIEndpointRef)endpoint
{
    //[delegate midiInput:self event:@"Removed a device"];

    PGMidiDestination *destination = [self getDestination:endpoint];

    if (destination)
    {
        [delegate midi:self destinationRemoved:destination];
        [destinations removeObject:destination];
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
