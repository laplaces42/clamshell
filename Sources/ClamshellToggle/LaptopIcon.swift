import AppKit

enum LaptopIcon {
    /// Template image: an open laptop when idle, a closed (filled) laptop when clamshell mode is on.
    static func image(closed: Bool, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width / 18
            NSColor.black.set()

            if closed {
                let body = NSBezierPath(roundedRect: NSRect(x: 1 * s, y: 6 * s, width: 16 * s, height: 4.5 * s),
                                        xRadius: 1.6 * s, yRadius: 1.6 * s)
                body.fill()
                // Small hinge-side notch so it reads as a laptop, not a bar.
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(roundedRect: NSRect(x: 7 * s, y: 6 * s, width: 4 * s, height: 1.2 * s),
                             xRadius: 0.6 * s, yRadius: 0.6 * s).fill()
            } else {
                let screen = NSBezierPath(roundedRect: NSRect(x: 3.5 * s, y: 6 * s, width: 11 * s, height: 8 * s),
                                          xRadius: 1.4 * s, yRadius: 1.4 * s)
                screen.lineWidth = 1.3 * s
                screen.stroke()
                let base = NSBezierPath(roundedRect: NSRect(x: 1 * s, y: 4 * s, width: 16 * s, height: 2 * s),
                                        xRadius: 1 * s, yRadius: 1 * s)
                base.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
