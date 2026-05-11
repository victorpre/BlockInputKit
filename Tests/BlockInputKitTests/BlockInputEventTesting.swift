import AppKit
import XCTest

func mouseDownEvent(windowNumber: Int) throws -> NSEvent {
    try XCTUnwrap(NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    ))
}

func keyDownEvent(keyCode: UInt16, characters: String) throws -> NSEvent {
    try XCTUnwrap(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode
    ))
}

func commandAEvent() throws -> NSEvent {
    try XCTUnwrap(NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: .command,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "a",
        charactersIgnoringModifiers: "a",
        isARepeat: false,
        keyCode: 0
    ))
}
