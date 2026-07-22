#!/usr/bin/env swift
import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
let rect = NSRect(origin: .zero, size: size)
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 36, dy: 36), xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.19, alpha: 1),
    NSColor(calibratedRed: 0.20, green: 0.16, blue: 0.48, alpha: 1),
    NSColor(calibratedRed: 0.10, green: 0.56, blue: 0.78, alpha: 1)
])!
gradient.draw(in: path, angle: -45)

let shield = NSBezierPath()
shield.move(to: NSPoint(x: 512, y: 820))
shield.curve(to: NSPoint(x: 785, y: 704), controlPoint1: NSPoint(x: 620, y: 814), controlPoint2: NSPoint(x: 720, y: 770))
shield.line(to: NSPoint(x: 750, y: 400))
shield.curve(to: NSPoint(x: 512, y: 190), controlPoint1: NSPoint(x: 730, y: 300), controlPoint2: NSPoint(x: 635, y: 225))
shield.curve(to: NSPoint(x: 274, y: 400), controlPoint1: NSPoint(x: 389, y: 225), controlPoint2: NSPoint(x: 294, y: 300))
shield.line(to: NSPoint(x: 239, y: 704))
shield.curve(to: NSPoint(x: 512, y: 820), controlPoint1: NSPoint(x: 304, y: 770), controlPoint2: NSPoint(x: 404, y: 814))
shield.close()
NSColor.white.withAlphaComponent(0.94).setFill()
shield.fill()

let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: 512, y: 500), radius: 150, startAngle: 215, endAngle: -35, clockwise: false)
arc.lineWidth = 52
arc.lineCapStyle = .round
NSColor(calibratedRed: 0.18, green: 0.67, blue: 0.91, alpha: 1).setStroke()
arc.stroke()

let needle = NSBezierPath()
needle.move(to: NSPoint(x: 512, y: 500))
needle.line(to: NSPoint(x: 616, y: 596))
needle.lineWidth = 34
needle.lineCapStyle = .round
NSColor(calibratedRed: 0.19, green: 0.13, blue: 0.42, alpha: 1).setStroke()
needle.stroke()

NSColor(calibratedRed: 0.19, green: 0.13, blue: 0.42, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 476, y: 464, width: 72, height: 72)).fill()
image.unlockFocus()

 guard let tiff = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to render app icon\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: output), options: .atomic)
