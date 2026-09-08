// tvkey.m — sends Siri Remote presses and typed text to a booted tvOS simulator.
//
// Built and run by scripts/tv-remote.sh; do not invoke directly.
//
// Why this exists: from CoreSimulator 1155.4 (Xcode 27) the legacy Indigo keyboard service is
// handed to the in-guest `dtuhidd` daemon for the lifetime of the boot, so `idb ui key` /
// `idb ui remote` are refused ("Keyboard HID is suppressed"), and the Xcode 26.6 Simulator.app's
// own keyboard path is the same suppressed service. idb's DTUHID transport is gated off for
// Apple TV because dtuhidd exposes no Siri Remote *trackpad*; the keyboard usage codes it does
// carry are enough for focus navigation. This is idb's `FBSimulatorDTUHIDTransport` keyboard
// path reduced to one file: look up the device's digitizer service port through CoreSimulator,
// wrap it in a sim-to-host XPC connection, and send `IndigoKeyboardButtonEvent` messages.
//
// Usage: tvkey <udid> <up|down|left|right|select|menu|playpause|0xNN|type:TEXT>...
//   up/down/left/right  Siri Remote direction (HID arrow keys 0x52/0x51/0x50/0x4F)
//   select              Return (0x28) — activates the focused element
//   menu                Escape (0x29) — tvOS Menu / back
//   playpause           Consumer Play/Pause is not a keyboard usage; use the app's control instead
//   0xNN                any raw USB HID keyboard usage code
//   type:TEXT           types TEXT into the focused field (ASCII letters, digits, and . - _ = / : ! @ # space)

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <xpc/xpc.h>

@interface SimDevice : NSObject
@property (readonly) NSUUID *UDID;
- (mach_port_t)lookup:(NSString *)name error:(NSError **)error;
@end

@interface SimDeviceSet : NSObject
@property (readonly) NSArray<SimDevice *> *devices;
@end

@interface SimServiceContext : NSObject
+ (instancetype)sharedServiceContextForDeveloperDir:(NSString *)dir error:(NSError **)error;
- (SimDeviceSet *)defaultDeviceSetWithError:(NSError **)error;
@end

typedef xpc_object_t (*EndpointFn)(mach_port_t, uint64_t, uint64_t);
typedef xpc_connection_t (*ConnectionFn)(xpc_object_t);
typedef void (*Sim2HostFn)(xpc_connection_t);

static NSString *const kDigitizerService = @"com.apple.coredevice.feature.remote.hid.digitizer";

static xpc_object_t keyMessage(uint64_t usage, uint64_t state) {
    xpc_object_t payload = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(payload, "usageCode", usage);
    xpc_dictionary_set_uint64(payload, "state", state); // 1 = down, 2 = up
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "messageType", "IndigoKeyboardButtonEvent");
    xpc_dictionary_set_bool(message, "isBarrier", false);
    xpc_dictionary_set_string(message, "featureIdentifier", kDigitizerService.UTF8String);
    xpc_dictionary_set_value(message, "payload", payload);
    return message;
}

static void press(xpc_connection_t connection, uint64_t usage, BOOL shift) {
    if (shift) xpc_connection_send_message(connection, keyMessage(0xE1, 1));
    xpc_connection_send_message(connection, keyMessage(usage, 1));
    usleep(50000);
    xpc_connection_send_message(connection, keyMessage(usage, 2));
    if (shift) xpc_connection_send_message(connection, keyMessage(0xE1, 2));
}

static BOOL usageForCharacter(unichar ch, uint64_t *usage, BOOL *shift) {
    *shift = NO;
    if (ch >= 'a' && ch <= 'z') { *usage = 0x04 + (ch - 'a'); return YES; }
    if (ch >= 'A' && ch <= 'Z') { *usage = 0x04 + (ch - 'A'); *shift = YES; return YES; }
    if (ch >= '1' && ch <= '9') { *usage = 0x1E + (ch - '1'); return YES; }
    switch (ch) {
        case '0': *usage = 0x27; return YES;
        case ' ': *usage = 0x2C; return YES;
        case '-': *usage = 0x2D; return YES;
        case '_': *usage = 0x2D; *shift = YES; return YES;
        case '=': *usage = 0x2E; return YES;
        case '.': *usage = 0x37; return YES;
        case '/': *usage = 0x38; return YES;
        case ':': *usage = 0x33; *shift = YES; return YES;
        case '!': *usage = 0x1E; *shift = YES; return YES;
        case '@': *usage = 0x1F; *shift = YES; return YES;
        case '#': *usage = 0x20; *shift = YES; return YES;
        default: return NO;
    }
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 3) {
            fprintf(stderr, "usage: tvkey <udid> <up|down|left|right|select|menu|0xNN|type:TEXT>...\n");
            return 2;
        }
        NSDictionary<NSString *, NSNumber *> *named = @{
            @"right": @0x4F, @"left": @0x50, @"down": @0x51, @"up": @0x52, @"select": @0x28, @"menu": @0x29
        };
        NSError *error = nil;
        NSString *developerDir = @(getenv("DEVELOPER_DIR") ?: "/Applications/Xcode.app/Contents/Developer");
        SimServiceContext *context = [NSClassFromString(@"SimServiceContext") sharedServiceContextForDeveloperDir:developerDir error:&error];
        if (context == nil) { fprintf(stderr, "CoreSimulator context failed: %s\n", error.description.UTF8String); return 1; }
        SimDevice *device = nil;
        for (SimDevice *candidate in [context defaultDeviceSetWithError:&error].devices) {
            if ([candidate.UDID.UUIDString caseInsensitiveCompare:@(argv[1])] == NSOrderedSame) device = candidate;
        }
        if (device == nil) { fprintf(stderr, "no simulator with UDID %s\n", argv[1]); return 1; }
        mach_port_t port = [device lookup:kDigitizerService error:&error];
        if (port == 0) { fprintf(stderr, "dtuhidd digitizer service lookup failed (is the device booted?): %s\n", error.description.UTF8String); return 1; }

        void *handle = dlopen(NULL, RTLD_NOW);
        EndpointFn endpointFromPort = dlsym(handle, "xpc_endpoint_create_mach_port_4sim");
        ConnectionFn connectionFromEndpoint = dlsym(handle, "xpc_connection_create_from_endpoint");
        Sim2HostFn enableSim2Host = dlsym(handle, "xpc_connection_enable_sim2host_4sim");
        if (endpointFromPort == NULL || connectionFromEndpoint == NULL || enableSim2Host == NULL) {
            fprintf(stderr, "private XPC endpoint symbols missing on this macOS\n");
            return 1;
        }
        xpc_connection_t connection = connectionFromEndpoint(endpointFromPort(port, 0, 0));
        if (connection == NULL) { fprintf(stderr, "could not open the dtuhidd connection\n"); return 1; }
        enableSim2Host(connection); // without this the daemon sees the peer but never the payload
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) { (void)event; });
        xpc_connection_resume(connection);

        for (int i = 2; i < argc; i++) {
            NSString *argument = @(argv[i]);
            if ([argument hasPrefix:@"type:"]) {
                NSString *text = [argument substringFromIndex:5];
                for (NSUInteger index = 0; index < text.length; index++) {
                    uint64_t usage = 0; BOOL shift = NO;
                    if (usageForCharacter([text characterAtIndex:index], &usage, &shift) == NO) {
                        fprintf(stderr, "unmapped character at %lu, skipped\n", (unsigned long)index);
                        continue;
                    }
                    press(connection, usage, shift);
                    usleep(90000);
                }
                printf("typed %lu characters\n", (unsigned long)text.length);
                continue;
            }
            uint64_t usage = named[argument] ? named[argument].unsignedLongLongValue : strtoull(argv[i], NULL, 0);
            if (usage == 0) { fprintf(stderr, "unknown action %s\n", argv[i]); return 2; }
            press(connection, usage, NO);
            dispatch_semaphore_t barrier = dispatch_semaphore_create(0);
            xpc_connection_send_barrier(connection, ^{ dispatch_semaphore_signal(barrier); });
            dispatch_semaphore_wait(barrier, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
            usleep(400000); // let the focus engine settle before the next press
            printf("sent %s (0x%llx)\n", argv[i], usage);
        }
        usleep(300000); // drain: dtuhidd consumes asynchronously
        xpc_connection_cancel(connection);
    }
    return 0;
}
