#!/usr/bin/env swift
// wechat_tool.swift — Flexible macOS UI automation tool for WeChat
// Usage:
//   swift wechat_tool.swift click <x> <y>           — Click at screen coordinates
//   swift wechat_tool.swift doubleclick <x> <y>      — Double click
//   swift wechat_tool.swift type <text>               — Paste text via clipboard + Cmd+V
//   swift wechat_tool.swift enter                     — Press Enter/Return
//   swift wechat_tool.swift key <keycode>             — Press a key by virtual keycode
//   swift wechat_tool.swift hotkey <modifier> <key>   — Press hotkey (e.g. hotkey cmd f)
//   swift wechat_tool.swift hover <x> <y>              — Move mouse without clicking (for scroll targeting)
//   swift wechat_tool.swift scroll <amount>           — Scroll vertically (positive=up, negative=down)
//   swift wechat_tool.swift screenshot [region]       — Take screenshot, optional x,y,w,h
//   swift wechat_tool.swift activate                  — Bring WeChat to front
//   swift wechat_tool.swift ax-find [role]            — Find UI elements via Accessibility API
//   swift wechat_tool.swift screen-size               — Print screen dimensions
//   swift wechat_tool.swift ocr <x,y,w,h> [text]     — Screenshot + OCR, returns screen coords
//   swift wechat_tool.swift find-click <text> <x,y,w,h> — Screenshot + OCR + click matched text

import Foundation
import CoreGraphics
import AppKit
import ApplicationServices
import Vision

// MARK: - Mouse

func click(x: Double, y: Double) {
    let point = CGPoint(x: x, y: y)
    let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    down?.post(tap: .cghidEventTap)
    usleep(50_000)
    up?.post(tap: .cghidEventTap)
    print("clicked \(Int(x)),\(Int(y))")
}

func doubleClick(x: Double, y: Double) {
    let point = CGPoint(x: x, y: y)
    let down1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    let up1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    let down2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    let up2 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    down2?.setIntegerValueField(.mouseEventClickState, value: 2)
    up2?.setIntegerValueField(.mouseEventClickState, value: 2)
    down1?.post(tap: .cghidEventTap); usleep(30_000)
    up1?.post(tap: .cghidEventTap); usleep(30_000)
    down2?.post(tap: .cghidEventTap); usleep(30_000)
    up2?.post(tap: .cghidEventTap)
    print("doubleclicked \(Int(x)),\(Int(y))")
}

// MARK: - Keyboard

func pressKey(_ keyCode: CGKeyCode) {
    let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    down?.post(tap: .cghidEventTap)
    usleep(50_000)
    up?.post(tap: .cghidEventTap)
    print("key \(keyCode)")
}

// WeChat ignores CGEvent key presses for some keys (e.g. Enter).
// Use osascript + System Events as a reliable fallback.
func pressKeyViaSystemEvents(_ keyCode: Int) {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", """
        tell application "System Events"
            tell process "WeChat"
                key code \(keyCode)
            end tell
        end tell
    """]
    try? proc.run(); proc.waitUntilExit()
    print("syskey \(keyCode)")
}

func pressHotkey(modifier: String, key: String) {
    let keyMap: [String: CGKeyCode] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "g": 0x05, "h": 0x04,
        "j": 0x26, "k": 0x28, "l": 0x25, "z": 0x06, "x": 0x07, "c": 0x08,
        "v": 0x09, "b": 0x0B, "n": 0x2D, "m": 0x2E, "q": 0x0C, "w": 0x0D,
        "e": 0x0E, "r": 0x0F, "t": 0x11, "y": 0x10, "u": 0x20, "i": 0x22,
        "o": 0x1F, "p": 0x23, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
        "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,
        "tab": 0x30, "space": 0x31, "return": 0x24, "escape": 0x35,
        "delete": 0x33, "up": 0x7E, "down": 0x7D, "left": 0x7B, "right": 0x7C,
    ]
    let modMap: [String: CGEventFlags] = [
        "cmd": .maskCommand, "shift": .maskShift,
        "alt": .maskAlternate, "ctrl": .maskControl,
    ]
    guard let kc = keyMap[key.lowercased()] else {
        print("error: unknown key '\(key)'"); return
    }
    guard let flag = modMap[modifier.lowercased()] else {
        print("error: unknown modifier '\(modifier)' (use cmd/shift/alt/ctrl)"); return
    }
    let down = CGEvent(keyboardEventSource: nil, virtualKey: kc, keyDown: true)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: kc, keyDown: false)
    down?.flags = flag; up?.flags = flag
    down?.post(tap: .cghidEventTap)
    usleep(50_000)
    up?.post(tap: .cghidEventTap)
    print("hotkey \(modifier)+\(key)")
}

// MARK: - Text Input (clipboard + paste)

func typeText(_ text: String) {
    let pb = NSPasteboard.general
    let oldContents = pb.string(forType: .string)
    pb.clearContents()
    pb.setString(text, forType: .string)
    usleep(100_000)
    pressHotkey(modifier: "cmd", key: "v")
    usleep(200_000)
    // Restore old clipboard
    if let old = oldContents {
        pb.clearContents()
        pb.setString(old, forType: .string)
    }
    print("typed \(text.prefix(50))\(text.count > 50 ? "..." : "")")
}

// MARK: - Hover (move mouse without clicking)

func hover(x: Double, y: Double) {
    let point = CGPoint(x: x, y: y)
    if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
        event.post(tap: .cghidEventTap)
    }
    print("hover \(Int(x)),\(Int(y))")
}

// MARK: - Scroll

func scroll(amount: Int32) {
    let iterations = abs(amount) / 5 + 1
    let perScroll: Int32 = amount > 0 ? 5 : -5
    for _ in 0..<iterations {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line,
                           wheelCount: 1, wheel1: perScroll, wheel2: 0, wheel3: 0)
        event?.post(tap: .cghidEventTap)
        usleep(60_000)
    }
    print("scrolled \(amount)")
}

// MARK: - Screenshot

func screenshot(region: String?, path: String) {
    var args = ["-x"]
    if let r = region {
        args += ["-R", r]
    }
    args.append(path)
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    proc.arguments = args
    try? proc.run(); proc.waitUntilExit()
    print("screenshot \(path)")
}

// MARK: - Activate WeChat

func activateWeChat() {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", "tell application \"WeChat\" to activate"]
    try? proc.run(); proc.waitUntilExit()
    usleep(500_000)
    print("activated WeChat")
}

// MARK: - Accessibility: find UI elements

func axFind(targetRole: String?) {
    let apps = NSWorkspace.shared.runningApplications
    guard let wechat = apps.first(where: {
        $0.localizedName == "微信" || $0.bundleIdentifier?.contains("xinWeChat") == true
    }) else {
        print("error: WeChat not running"); return
    }
    print("pid \(wechat.processIdentifier)")
    let app = AXUIElementCreateApplication(wechat.processIdentifier)

    // Get windows
    var winRef: CFTypeRef?
    AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &winRef)
    if let windows = winRef as? [AXUIElement] {
        for win in windows {
            var titleRef: CFTypeRef?
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef)
            var pos = CGPoint.zero; var size = CGSize.zero
            if let p = posRef { AXValueGetValue(p as! AXValue, .cgPoint, &pos) }
            if let s = sizeRef { AXValueGetValue(s as! AXValue, .cgSize, &size) }
            print("window \"\(titleRef as? String ?? "")\" pos:\(Int(pos.x)),\(Int(pos.y)) size:\(Int(size.width)),\(Int(size.height))")
        }
    }

    // Recursively find elements
    func walk(_ el: AXUIElement, depth: Int) {
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        var posRef: CFTypeRef?; var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef)
        var pos = CGPoint.zero; var size = CGSize.zero
        if let p = posRef { AXValueGetValue(p as! AXValue, .cgPoint, &pos) }
        if let s = sizeRef { AXValueGetValue(s as! AXValue, .cgSize, &size) }

        let matchAll = targetRole == nil || targetRole == "all"
        let matchRole = targetRole != nil && role.lowercased().contains(targetRole!.lowercased())

        if matchAll || matchRole {
            var descRef: CFTypeRef?; var valRef: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &valRef)
            let desc = descRef as? String ?? ""
            let val = (valRef as? String ?? "").prefix(80)
            print("  [\(depth)] \(role) pos:\(Int(pos.x)),\(Int(pos.y)) size:\(Int(size.width)),\(Int(size.height)) desc:\(desc) val:\(val)")
        }

        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement], depth < 12 else { return }
        for child in children { walk(child, depth: depth + 1) }
    }
    walk(app, depth: 0)
}

// MARK: - OCR (screenshot + Vision OCR + screen coordinate conversion)

func parseRegion(_ regionStr: String) -> CGRect? {
    let parts = regionStr.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 4 else { return nil }
    return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
}

func captureRegion(_ rect: CGRect) -> CGImage? {
    let tmpPath = "/tmp/_wc_ocr_\(ProcessInfo.processInfo.processIdentifier).png"
    let regionStr = "\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))"
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    proc.arguments = ["-x", "-R", regionStr, tmpPath]
    try? proc.run(); proc.waitUntilExit()
    guard let nsImage = NSImage(contentsOfFile: tmpPath),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return nil
    }
    try? FileManager.default.removeItem(atPath: tmpPath)
    return cgImage
}

func runOCR(image: CGImage, searchText: String?, region: CGRect) -> [(text: String, screenX: Int, screenY: Int, sx: Int, sy: Int, sw: Int, sh: Int)] {
    let imgW = CGFloat(image.width)
    let imgH = CGFloat(image.height)
    let scaleX = imgW / region.width
    let scaleY = imgH / region.height

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try? handler.perform([request])

    var results: [(text: String, screenX: Int, screenY: Int, sx: Int, sy: Int, sw: Int, sh: Int)] = []
    guard let observations = request.results else { return results }

    for obs in observations {
        guard let candidate = obs.topCandidates(1).first else { continue }
        let text = candidate.string

        if let search = searchText, !text.localizedCaseInsensitiveContains(search) {
            continue
        }

        let bbox = obs.boundingBox
        // Pixel coords in image
        let px = bbox.origin.x * imgW
        let py = (1 - bbox.origin.y - bbox.height) * imgH
        let pw = bbox.width * imgW
        let ph = bbox.height * imgH
        // Convert to screen coords
        let sx = Int(region.origin.x + px / scaleX)
        let sy = Int(region.origin.y + py / scaleY)
        let sw = Int(pw / scaleX)
        let sh = Int(ph / scaleY)
        let cx = sx + sw / 2
        let cy = sy + sh / 2

        results.append((text: text, screenX: cx, screenY: cy, sx: sx, sy: sy, sw: sw, sh: sh))
    }
    return results
}

func ocrCommand(regionStr: String, searchText: String?) {
    guard let rect = parseRegion(regionStr) else {
        print("error: invalid region '\(regionStr)', expected x,y,w,h"); return
    }
    guard let image = captureRegion(rect) else {
        print("error: screenshot failed"); return
    }
    let results = runOCR(image: image, searchText: searchText, region: rect)
    if results.isEmpty {
        print("no text found\(searchText != nil ? " matching '\(searchText!)'" : "")")
    }
    for r in results {
        print("\(r.text) | screen_center:\(r.screenX),\(r.screenY) | screen_bbox:\(r.sx),\(r.sy),\(r.sw),\(r.sh)")
    }
}

func findClickCommand(searchText: String, regionStr: String) {
    guard let rect = parseRegion(regionStr) else {
        print("error: invalid region '\(regionStr)', expected x,y,w,h"); return
    }
    guard let image = captureRegion(rect) else {
        print("error: screenshot failed"); return
    }
    let results = runOCR(image: image, searchText: searchText, region: rect)
    guard let first = results.first else {
        print("error: text '\(searchText)' not found in region \(regionStr)")
        return
    }
    print("found '\(first.text)' at screen \(first.screenX),\(first.screenY)")
    click(x: Double(first.screenX), y: Double(first.screenY))
}

// MARK: - Screen Size

func screenSize() {
    let d = CGMainDisplayID()
    print("screen \(CGDisplayPixelsWide(d))x\(CGDisplayPixelsHigh(d))")
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("""
    wechat_tool.swift — macOS WeChat UI automation
    Commands:
      click <x> <y>             Click at coordinates
      doubleclick <x> <y>       Double-click
      type <text...>            Paste text (clipboard + Cmd+V)
      enter                     Press Enter
      key <keycode>             Press key by code (decimal)
      hotkey <mod> <key>        Press modifier+key (e.g. cmd f)
      hover <x> <y>             Move mouse without clicking
      scroll <amount>           Scroll (positive=up, negative=down)
      screenshot [x,y,w,h] <path>  Take screenshot
      activate                  Bring WeChat to front
      ax-find [role]            Find AX elements (e.g. TextField, Button, all)
      screen-size               Print screen dimensions
    """)
    exit(1)
}

switch args[1] {
case "click":
    guard args.count >= 4, let x = Double(args[2]), let y = Double(args[3]) else {
        print("usage: click <x> <y>"); exit(1)
    }
    click(x: x, y: y)

case "doubleclick":
    guard args.count >= 4, let x = Double(args[2]), let y = Double(args[3]) else {
        print("usage: doubleclick <x> <y>"); exit(1)
    }
    doubleClick(x: x, y: y)

case "type":
    guard args.count >= 3 else { print("usage: type <text>"); exit(1) }
    typeText(args.dropFirst(2).joined(separator: " "))

case "enter":
    pressKeyViaSystemEvents(36)  // Return key via osascript (WeChat ignores CGEvent Enter)

case "key":
    guard args.count >= 3, let code = UInt16(args[2]) else {
        print("usage: key <keycode>"); exit(1)
    }
    pressKey(code)

case "hotkey":
    guard args.count >= 4 else { print("usage: hotkey <mod> <key>"); exit(1) }
    pressHotkey(modifier: args[2], key: args[3])

case "hover":
    guard args.count >= 4, let x = Double(args[2]), let y = Double(args[3]) else {
        print("usage: hover <x> <y>"); exit(1)
    }
    hover(x: x, y: y)

case "scroll":
    guard args.count >= 3, let amt = Int32(args[2]) else {
        print("usage: scroll <amount>"); exit(1)
    }
    scroll(amount: amt)

case "screenshot":
    if args.count >= 4 {
        screenshot(region: args[2], path: args[3])
    } else if args.count >= 3 {
        screenshot(region: nil, path: args[2])
    } else {
        screenshot(region: nil, path: "/tmp/wechat_screen.png")
    }

case "activate":
    activateWeChat()

case "ax-find":
    let role = args.count >= 3 ? args[2] : nil
    axFind(targetRole: role)

case "screen-size":
    screenSize()

case "ocr":
    // ocr <x,y,w,h> [search_text]
    guard args.count >= 3 else { print("usage: ocr <x,y,w,h> [search_text]"); exit(1) }
    let search = args.count >= 4 ? args[3...].joined(separator: " ") : nil
    ocrCommand(regionStr: args[2], searchText: search)

case "find-click":
    // find-click <search_text> <x,y,w,h>
    guard args.count >= 4 else { print("usage: find-click <search_text> <x,y,w,h>"); exit(1) }
    findClickCommand(searchText: args[2], regionStr: args[3])

default:
    print("unknown command: \(args[1])")
    exit(1)
}
