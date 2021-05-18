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
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>

static bool locked = false;
static int keyPos = 0;
static char lockStr[] = "lock31337";  // any random str, unlikely to be typed by accident, 0 Google results
static char unlockStr[] = "unlock";

static const char* getCmdStr() { return locked ? unlockStr : lockStr; }
static const char* getCmdName() { return locked ? "unlock" : "lock"; }
static const char* getLockedStateName() { return locked ? "locked" : "unlocked"; }

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    CGEventRef returnEvent = locked ? NULL : event;

    if(type == kCGEventKeyDown) {
        printf("event %i", type);
        
        CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        printf(", key code %i", keyCode);

        UniChar keyUniStr[16];
        UniCharCount keyUniStrLen = 0;
        CGEventKeyboardGetUnicodeString(
            event, sizeof(keyUniStr) / sizeof(keyUniStr[0]) - 1, &keyUniStrLen, keyUniStr);

        char c = (keyUniStrLen > 0 && keyUniStr[0] < 128) ? keyUniStr[0] : 0;
        const char* cmdName = getCmdName();
        const char* cmdStr = getCmdStr();
        int cmdStrLen = strlen(cmdStr);
        if(keyPos > cmdStrLen) keyPos = 0;

        printf(", char %i (expected %i)", c, cmdStr[keyPos]);

        if(c == cmdStr[keyPos]) {
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

int main(void) {
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
        fprintf(stderr, "Failed to create event tap for keyboard events\n");
        return 1;
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);

    CGEventTapEnable(eventTap, true);

    printf("Event trap is activated.\n");
    printf("Current state: %s\n", getLockedStateName());
    printf("Type '%s' to lock, and '%s' to unlock.\n", lockStr, unlockStr);

    CFRunLoopRun();
    return 0;
}

