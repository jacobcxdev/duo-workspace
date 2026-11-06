import AppKit
import Foundation

// Run from the repository root to regenerate app icons.
func icon(size: Int, rounded: Bool) throws -> Data {
    let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(size) / 1024)
    transform.concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024),
                                  xRadius: rounded ? 220 : 0, yRadius: rounded ? 220 : 0)
    NSGradient(starting: NSColor(red: 0.13, green: 0.40, blue: 0.83, alpha: 1),
               ending: NSColor(red: 0.04, green: 0.09, blue: 0.17, alpha: 1))!.draw(in: background, angle: -90)
    let frame = NSBezierPath(roundedRect: NSRect(x: 166, y: 255, width: 692, height: 514), xRadius: 66, yRadius: 66)
    NSColor(white: 1, alpha: 0.95).setFill(); frame.fill()
    let screen = NSBezierPath(roundedRect: NSRect(x: 197, y: 286, width: 630, height: 452), xRadius: 36, yRadius: 36)
    NSColor(red: 0.05, green: 0.12, blue: 0.23, alpha: 1).setFill(); screen.fill()
    NSColor(red: 0.51, green: 0.70, blue: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 232, y: 321, width: 240, height: 382), xRadius: 18, yRadius: 18).fill()
    NSColor(red: 0.15, green: 0.37, blue: 0.68, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 500, y: 321, width: 292, height: 382), xRadius: 18, yRadius: 18).fill()
    let cursor = NSBezierPath()
    cursor.move(to: NSPoint(x: 583, y: 592)); cursor.line(to: NSPoint(x: 583, y: 365))
    cursor.line(to: NSPoint(x: 639, y: 410)); cursor.line(to: NSPoint(x: 679, y: 334))
    cursor.line(to: NSPoint(x: 719, y: 354)); cursor.line(to: NSPoint(x: 682, y: 430))
    cursor.line(to: NSPoint(x: 753, y: 433)); cursor.close()
    NSColor.white.setFill(); cursor.fill()
    NSGraphicsContext.restoreGraphicsState()
    if !rounded {
        // Quartz drawing requires a supported four-channel surface. Flatten
        // only at export so the iOS icon is opaque without becoming blank.
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: size, height: size))
        return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    }
    return image.representation(using: .png, properties: [:])!
}

let manager = FileManager.default
for (platform, rounded) in [("iOS", false), ("macOS", true)] {
    let folder = URL(fileURLWithPath: "Apps/\(platform)/Assets.xcassets/AppIcon.appiconset")
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    var entries: [[String: String]] = []
    if platform == "iOS" {
        try icon(size: 1024, rounded: rounded).write(to: folder.appendingPathComponent("AppIcon.png"))
        entries.append(["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"])
    } else {
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let file = "AppIcon-\(points)@\(scale)x.png"
                try icon(size: points * scale, rounded: rounded).write(to: folder.appendingPathComponent(file))
                entries.append(["filename": file, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
            }
        }
    }
    let data = try JSONSerialization.data(withJSONObject: ["images": entries, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
    try data.write(to: folder.appendingPathComponent("Contents.json"))
    let root = folder.deletingLastPathComponent().appendingPathComponent("Contents.json")
    try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(to: root)
}
