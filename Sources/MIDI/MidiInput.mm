//
//  MidiInput.m
//  iDJ-Pro
//
//  Created by Pete Goodliffe on 10/12/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MidiInput.h"

#define NSLogError(c,str) do{if (c) NSLog(@"Error (%@): %u:%@", str, c,[NSError errorWithDomain:NSMachErrorDomain code:c userInfo:nil]);}while(false)

void MyMIDINotifyProc(const MIDINotification *message, void *refCon);
void MyMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);

@interface MidiInput ()
- (void) scanExistingDevices;
@end

//==============================================================================

@implementation MidiInput

@synthesize delegate;
@synthesize numberOfConnectedDevices;

- (id) init
{
    if ((self = [super init]))
    {
        [self scanExistingDevices];

        OSStatus s = MIDIClientCreate((CFStringRef)@"iDJ Pro MIDI Client", MyMIDINotifyProc, self, &client);
        NSLogError(s, @"Create MIDI client");

        s = MIDIOutputPortCreate(client, (CFStringRef)@"iDJ Pro Output Port", &outputPort);
        NSLogError(s, @"Create output MIDI port");

        s = MIDIInputPortCreate(client, (CFStringRef)@"iDJ Pro Input Port", MyMIDIReadProc, self, &inputPort);
        NSLogError(s, @"Create input MIDI port");
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

    [super dealloc];
}

//==============================================================================
#pragma mark Connect/disconnect

- (void) connectSource:(MIDIEndpointRef)source
{
    [delegate midiInput:self event:@"Added a source"];

    OSStatus s = MIDIPortConnectSource(inputPort, source, self);
    NSLogError(s, @"Connecting to MIDI source");
}

- (void) disconnectSource:(MIDIEndpointRef)source
{
    [delegate midiInput:self event:@"Removed a source"];

    OSStatus s = MIDIPortDisconnectSource(inputPort, source);
    NSLogError(s, @"Disconnecting from MIDI source");
}

- (void) connectDestination:(MIDIEndpointRef)destination
{
    [delegate midiInput:self event:@"Added a destination"];
}

- (void) disconnectDestination:(MIDIEndpointRef)destination
{
    [delegate midiInput:self event:@"Removed a device"];
}

- (void) scanExistingDevices
{
    const ItemCount numberOfDestinations = MIDIGetNumberOfDestinations();
    const ItemCount numberOfSources      = MIDIGetNumberOfSources();

    for (ItemCount index = 0; index < numberOfDestinations; ++index)
        [self connectDestination:MIDIGetDestination(index)];
    for (ItemCount index = 0; index < numberOfSources; ++index)
        [self connectDestination:MIDIGetSource(index)];
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

void MyMIDINotifyProc(const MIDINotification *message, void *refCon)
{
    MidiInput *self = (MidiInput*)refCon;
    [self midiNotify:message];
}

//==============================================================================
#pragma mark MIDI I/O

- (void) mentionInput
{
    [delegate midiInput:self event:@"Read some MIDI"];
}

// NOTE: Called on a separate high-priority thread, not the main runloop
- (void) midiRead:(const MIDIPacketList *)pktlist
{
    //[self performSelectorOnMainThread:@selector(mentionInput) withObject:nil waitUntilDone:NO];
    [delegate midiInput:self midiReceived:pktlist];
}

void MyMIDIReadProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
    MidiInput *self = (MidiInput*)readProcRefCon;
    [self midiRead:pktlist];
}

@end

//==============================================================================

NSUInteger ListInterfaces()
{
    NSLog(@"%s: # external devices=%u", __func__, MIDIGetNumberOfExternalDevices());
    NSLog(@"%s: # devices=%u", __func__, MIDIGetNumberOfDevices());
    NSLog(@"%s: # sources=%u", __func__, MIDIGetNumberOfSources());
    NSLog(@"%s: # destinations=%u", __func__, MIDIGetNumberOfDestinations());

    MIDIClientRef  client = 0;
    CFStringRef    clientName = (CFStringRef)@"MIDI Updater";
    MIDINotifyProc notifyProc = nil;
    OSStatus s = MIDIClientCreate(clientName, notifyProc, nil, &client);
    NSLogError(s, @"Creating MIDI client");

    for (ItemCount index = 0; index < MIDIGetNumberOfExternalDevices(); ++index)
    {
        NSLog(@"%s: index %u", __func__, index);
        MIDIDeviceRef device = MIDIGetDevice(index);
        if (device)
        {
            //CFRelease(device);
        }
    }

    for (ItemCount index = 0; index < MIDIGetNumberOfDestinations(); ++index)
    {
        MIDIEndpointRef endpoint = MIDIGetDestination(index);
        if (endpoint)
        {
            NSLog(@"%s:   destination index %u", __func__, index);
            CFStringRef name = nil;
            OSStatus s = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name);
            if (s)
                NSLogError(s, @"Getting dest name");
            else
                NSLog(@"Name=%@", name);
            CFRelease(name);

            CFPropertyListRef properties = nil;
            s = MIDIObjectGetProperties(endpoint, &properties, true);
            if (s)
                NSLogError(s, @"Getting properties");
            else
                NSLog(@"Properties=%@", properties);
            CFRelease(properties); properties = nil;

            MIDIEntityRef entity = 0;
            s = MIDIEndpointGetEntity(endpoint, &entity);

            s = MIDIObjectGetProperties(entity, &properties, true);
            if (s)
                NSLogError(s, @"Getting entity properties");
            else
                NSLog(@"Entity properties=%@", properties);
            CFRelease(properties); properties = nil;

            SInt32 offline = 0;
            s = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &offline);
            if (s)
                NSLogError(s, @"Getting offline properties");
            else
                NSLog(@"Entity offline=%d", offline);

            //CFRelease(entity); entity = nil;

            //CFRelease(endpoint);
            NSLog(@"Done");
        }
    }

    if (client)
        MIDIClientDispose(client);

    NSLog(@"Found all interfaces");

    return MIDIGetNumberOfDestinations();
}
