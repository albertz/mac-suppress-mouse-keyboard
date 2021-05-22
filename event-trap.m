/*
Catches all events (mouse, keyboard, everything),
and either consumes them (locked state)
or passes them through (unlocked state).
The locked state can be switched by the magic commands
(see code below).

compile:

    clang -o event-trap.bin event-trap.m -framework Cocoa

run:

    sudo ./event-trap.bin
*/

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>


static void showHudForKey(char c) {

    NSWindow* window = [NSWindow new];

    window.titleVisibility = NSWindowTitleHidden;
    window.styleMask = NSWindowStyleMaskBorderless;
    window.alphaValue = 0.9;
    window.movableByWindowBackground = YES;

    [window setLevel: NSStatusWindowLevel];
    [window setBackgroundColor: [NSColor clearColor]];
    [window setOpaque:NO];
    //[window setHasShadow:NO];

    [window makeKeyAndOrderFront:NSApp];

    NSVisualEffectView *view = [[NSVisualEffectView new] initWithFrame:window.contentView.bounds];;

    view.translatesAutoresizingMaskIntoConstraints = NO;

    [view setBlendingMode:NSVisualEffectBlendingModeBehindWindow];
    [view setMaterial:NSVisualEffectMaterialDark];
    [view setState:NSVisualEffectStateActive];

    //[view setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];

    //[view setWantsLayer:NO];
    [view setWantsLayer:YES];
    view.layer.cornerRadius = 16.;
    //view.layer.shouldRasterize = YES;
    //view.layer.rasterizationScale = 0.45;
    view.layer.shadowOpacity = 0.1; //0.01;
    view.layer.edgeAntialiasingMask = kCALayerTopEdge | kCALayerBottomEdge | kCALayerRightEdge | kCALayerLeftEdge;

    [window.contentView addSubview:view];
    //window.contentView = view;

    NSTextField *label = [[NSTextField alloc] initWithFrame:view.bounds];

    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    
    label.stringValue = [NSString stringWithFormat:@"%c", c];
    label.alignment = NSTextAlignmentCenter;
    label.textColor = [NSColor whiteColor];
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont fontWithName:@"Arial-BoldMT" size:50];

    NSSize strSize = [label.attributedStringValue size];
    NSRect frame = view.frame;
    frame.origin.y = frame.size.height / 2 -  strSize.height / 2;
    frame.size.height = strSize.height;
    label.frame = frame;
 
    [view addSubview:label];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.25;
        window.animator.alphaValue = 0.;
    } completionHandler:^{
        [window close];
    }];

}

static bool locked = false;
static int keyPos = 0;
static char lockStr[] = "lock31337";  // any random str, unlikely to be typed by accident, 0 Google results
static char unlockStr[] = "unlock";

static const char* getCmdStr() { return locked ? unlockStr : lockStr; }
static const char* getCmdName() { return locked ? "unlock" : "lock"; }
static const char* getLockedStateName() { return locked ? "locked" : "unlocked"; }

static CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    CGEventRef returnEvent = locked ? NULL : event;

    if(type == kCGEventKeyDown) {
        printf("event %i", type);
        
        CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        printf(", key code %i", keyCode);

        UniChar keyUniStr[16];
        UniCharCount keyUniStrLen = 0;
        CGEventKeyboardGetUnicodeString(
            event, sizeof(keyUniStr) / sizeof(keyUniStr[0]) - 1, &keyUniStrLen, keyUniStr);

        char c = (keyUniStrLen > 0 && keyUniStr[0] < 128) ? tolower(keyUniStr[0]) : 0;
        const char* cmdName = getCmdName();
        const char* cmdStr = getCmdStr();
        int cmdStrLen = strlen(cmdStr);
        if(keyPos > cmdStrLen) keyPos = 0;

        printf(", char %i (expected %i)", c, cmdStr[keyPos]);
        if(locked && c)
            showHudForKey(toupper(c));

        if(c == cmdStr[keyPos] || c == cmdStr[0]) {
            if(c != cmdStr[keyPos] && c == cmdStr[0]) keyPos = 0;
            ++keyPos;
            printf(", match (pos %i, len %i), remaining '%s'", keyPos, cmdStrLen, cmdStr + keyPos);
            if(keyPos >= cmdStrLen) {
                printf(", %s!", cmdName);
                locked = !locked;
                keyPos = 0;
            }
        }
        else {
            keyPos = 0;
            printf(" (type '%s' to %s)", cmdStr, cmdName);
        }

        printf("\n");
    }

    return returnEvent;
}

int main(int argc, const char * argv[]) {
    CGEventMask eventMask;
    CFMachPortRef eventTap;

    // First test for key events. This fails when we are not allowed to do so.
    // We should be allowed by either being root (sudo),
    // or add binary to: system preferences -> security -> privacy -> accessibility.
    eventMask = CGEventMaskBit(kCGEventKeyDown);
    eventTap = CGEventTapCreate(
        kCGSessionEventTap, kCGHeadInsertEventTap, 0, eventMask, myCGEventCallback, NULL);
    if(!eventTap) {
        fprintf(stderr, "Failed to create event tap for keyboard events.\n");
        fprintf(stderr, "Run with sudo, or add binary to: system preferences -> security -> privacy -> accessibility\n");
        return 1;
    }
    CFRelease(eventTap);
    
    eventMask = -1; // just all!
    eventTap = CGEventTapCreate(
        kCGSessionEventTap, kCGHeadInsertEventTap, 0, eventMask, myCGEventCallback, NULL);
    if(!eventTap) {
        fprintf(stderr, "Failed to create event tap.\n");
        return 1;
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);

    CGEventTapEnable(eventTap, true);

    printf("Event trap is activated.\n");
    printf("Current state: %s\n", getLockedStateName());
    printf("Type '%s' to lock, and '%s' to unlock.\n", lockStr, unlockStr);

    // like NSApplicationMain(argc, argv)
    [NSApplication sharedApplication];
    // no delegate needed
    [NSApp run];

    // We normally would not reach this code.
    // But this would be used if we would not use the NSApp main loop above.
    CFRunLoopRun();
    return 0;
}

