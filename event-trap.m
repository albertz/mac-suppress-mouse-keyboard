

/*

compile: clang -o event-trap.bin event-trap.m -framework Cocoa -framework Carbon

*/

#include <stdio.h>
#include <string.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

static bool locked = false;
static int keyPos = 0;
static char lockStr[] = "lock31337";  // any random str, unlikely to be typed by accident, 0 Google results
static char unlockStr[] = "unlock";

static char getCharFromKeyCode(CGKeyCode keyCode) {
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef uchr = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout*)CFDataGetBytePtr(uchr);

    if(keyboardLayout) {
        UInt32 deadKeyState = 0;
        UniCharCount maxStringLength = 16;
        UniCharCount actualStringLength = 0;
        UniChar unicodeString[maxStringLength];

        OSStatus status = UCKeyTranslate(
            keyboardLayout,
            keyCode, kUCKeyActionDown, 0,
            LMGetKbdType(), 0,
            &deadKeyState,
            maxStringLength,
            &actualStringLength, unicodeString);

        if(actualStringLength > 0 && status == noErr) {
            if(unicodeString[0] < 128)
                return (char) unicodeString[0];
        }
    }

    return 0;
}

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    CGEventRef returnEvent = locked ? NULL : event;

    if(type == kCGEventKeyDown) {
        printf("event %i", type);
        
        CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        printf(", key code %i", keyCode);

        char c = getCharFromKeyCode(keyCode);
        const char* cmdName = locked ? "unlock" : "lock";
        const char* cmdStr = locked ? unlockStr : lockStr;
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

    CFRunLoopRun();
    return 0;
}

