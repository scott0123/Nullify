//
//  AppDelegate.m
//  Nullify
//
//  Created by ScottLiu on 9/13/18.
//  Copyright © 2018 Scott Liu. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()


@end

@implementation AppDelegate

bool trackpadSuppressed = false;
bool keyboardSuppressed = false;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [self PutStatusItemOnSystemBar];
    [self MakeMenusWork];
    
    if([self acquirePrivileges]){
        CreateEventTap();
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Important"];
        [alert setInformativeText:@"You must grant accessibility permissions to use the features of this app. After that is done, fully exit and restart this app."];
        [alert addButtonWithTitle:@"Ok"];
        [alert runModal];
    }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)PutStatusItemOnSystemBar {
    
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    // The text that will be shown in the menu bar
    self.statusItem.title = @"";
    
    // The image that will be shown in the menu bar, a 16x16 black png works best
    self.statusItem.image = [NSImage imageNamed:@"StatusBarButtonImage"];
    [self.statusItem.image setTemplate:YES];
    
    // The image gets a blue background when the item is selected
    self.statusItem.highlightMode = YES;
}

- (void)MakeMenusWork {
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    [[menu addItemWithTitle:@"Enable All" action:@selector(OptionOne) keyEquivalent:@""] setTarget:self];
    [[menu addItemWithTitle:@"Disable Keyboard" action:@selector(OptionTwo) keyEquivalent:@""] setTarget:self];
    [[menu addItemWithTitle:@"Disable Keyboard and Trackpad" action:@selector(OptionThree) keyEquivalent:@""] setTarget:self];
    
    [menu addItem:[NSMenuItem separatorItem]]; // A thin grey line
    
    [[menu addItemWithTitle:@"Quit Nullify" action:@selector(Quit) keyEquivalent:@""] setTarget:self];
    
    self.statusItem.menu = menu;
}


- (void)OptionOne {
    keyboardSuppressed = false;
    trackpadSuppressed = false;
}
- (void)OptionTwo {
    keyboardSuppressed = true;
}
- (void)OptionThree {
    keyboardSuppressed = true;
    trackpadSuppressed = true;
}


- (void)Quit {
    [NSApp terminate:self];
}


// ------------------------------ event taps ------------------------------
void CreateEventTap() {
    
    // kCGHIDEventTap = system-wide tap
    // kCGSessionEventTap = session-wide tap
    // kCGAnnotatedSessionEventTap = application-wide tap
    CGEventTapLocation tap = kCGHIDEventTap;
    // place the tap at the very beginning
    CGEventTapPlacement place = kCGHeadInsertEventTap;
    // this will not be a listen-only tap
    CGEventTapOptions options = kCGEventTapOptionDefault;
    // OR the masks together
    CGEventMask eventsOfInterestMouseMoved =
      CGEventMaskBit(kCGEventMouseMoved)
    | CGEventMaskBit(kCGEventLeftMouseDragged)
    | CGEventMaskBit(kCGEventRightMouseDragged)
    ;
    CGEventMask eventsOfInterestMouseClicked =
      CGEventMaskBit(kCGEventLeftMouseDown)
    | CGEventMaskBit(kCGEventLeftMouseUp)
    | CGEventMaskBit(kCGEventRightMouseDown)
    | CGEventMaskBit(kCGEventRightMouseUp)
    ;
    CGEventMask eventsOfInterestMouseScrolled =
      CGEventMaskBit(kCGEventScrollWheel)
    ;
    CGEventMask eventsOfInterestKeyPressed =
      CGEventMaskBit(kCGEventKeyDown)
    | CGEventMaskBit(kCGEventKeyUp)
    ;
    
    // create the event tap for mouse moves
    CFMachPortRef mouseMovedEventTap = CGEventTapCreate(tap, place, options, eventsOfInterestMouseMoved, mouseMovedCallback, nil);
    // create the event tap for mouse clicks
    CFMachPortRef mouseClickedEventTap = CGEventTapCreate(tap, place, options, eventsOfInterestMouseClicked, mouseClickedCallback, nil);
    // create the event tap for mouse scrolls
    CFMachPortRef mouseScrolledEventTap = CGEventTapCreate(tap, place, options, eventsOfInterestMouseScrolled, mouseScrolledCallback, nil);
    // create the event tap for key downs
    CFMachPortRef keyPressedEventTap = CGEventTapCreate(tap, place, options, eventsOfInterestKeyPressed, keyPressedCallback, nil);
    
    // create a run loop source ref for mouse moves
    CFRunLoopSourceRef mouseMovedRunLoopSourceRef = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseMovedEventTap, 0);
    // create a run loop source ref for mouse clicks
    CFRunLoopSourceRef mouseClickedRunLoopSourceRef = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseClickedEventTap, 0);
    // create a run loop source ref for mouse clicks
    CFRunLoopSourceRef mouseScrolledRunLoopSourceRef = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseScrolledEventTap, 0);
    // create a run loop source ref for key downs
    CFRunLoopSourceRef keyPressedRunLoopSourceRef = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, keyPressedEventTap, 0);
    
    // add to the run loops
    CFRunLoopAddSource(CFRunLoopGetCurrent(), mouseMovedRunLoopSourceRef, kCFRunLoopCommonModes);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), mouseClickedRunLoopSourceRef, kCFRunLoopCommonModes);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), mouseScrolledRunLoopSourceRef, kCFRunLoopCommonModes);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), keyPressedRunLoopSourceRef, kCFRunLoopCommonModes);
    
    // Enable the event taps
    CGEventTapEnable(mouseMovedEventTap, true);
    CGEventTapEnable(mouseClickedEventTap, true);
    CGEventTapEnable(mouseScrolledEventTap, true);
    CGEventTapEnable(keyPressedEventTap, true);
}

CGEventRef mouseMovedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon){
    // unfortunately is it impossible to suppress mouse movements,
    // and thus we will only be warping it back to the original location
    NSEvent* e = [NSEvent eventWithCGEvent:event];
    if(trackpadSuppressed && e.subtype != NSEventSubtypeMouseEvent){
        CGWarpMouseCursorPosition(CGEventGetLocation(event));
        return nil;
    } else {
        return event;
    }
}

CGEventRef mouseClickedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon){
    NSEvent* e = [NSEvent eventWithCGEvent:event];
    if(trackpadSuppressed && e.subtype != NSEventSubtypeMouseEvent){
        return nil;
    } else {
        return event;
    }
}

CGEventRef mouseScrolledCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon){
    NSEvent* e = [NSEvent eventWithCGEvent:event];
    if(trackpadSuppressed && e.subtype != NSEventSubtypeMouseEvent){
        return nil;
    } else {
        return event;
    }
}

CGEventRef keyPressedCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon){
    if(keyboardSuppressed){
        return nil;
    } else {
        return event;
    }
}

// check priv
- (BOOL)acquirePrivileges {
    
    if (&AXIsProcessTrustedWithOptions != NULL) {
        // 10.9 and later
        const void * keys[] = { kAXTrustedCheckOptionPrompt };
        const void * values[] = { kCFBooleanTrue };
        
        CFDictionaryRef options = CFDictionaryCreate(
                                                     kCFAllocatorDefault,
                                                     keys,
                                                     values,
                                                     sizeof(keys) / sizeof(*keys),
                                                     &kCFCopyStringDictionaryKeyCallBacks,
                                                     &kCFTypeDictionaryValueCallBacks);
        
        return AXIsProcessTrustedWithOptions(options);
    }
}

@end
