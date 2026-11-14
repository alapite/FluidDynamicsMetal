import AppKit

/// A small, noninteractive orientation cue over the spatial canvas.
final class OrientationGuide3DView: NSView {
    var cameraState = CameraState3D() {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAccessibility()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAccessibility()
    }

    private func configureAccessibility() {
        setAccessibilityElement(true)
        setAccessibilityIdentifier("orientationGuide3d")
        setAccessibilityLabel("3D orientation guide: X, Y and Z axes")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let camera = try? Camera3D.frame(
            state: cameraState,
            viewportSize: CGSize(width: 1, height: 1)
        ) else { return }

        let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let gray = contrast ? CGFloat(0xD9) / 255 : CGFloat(0xA6) / 255
        let color = NSColor(calibratedWhite: gray, alpha: 1)
        let labels = ["X", "Y", "Z"]
        let axes = camera.axisProjections.enumerated().map { index, projection in
            (
                label: labels[index],
                x: CGFloat(projection.x) * 20,
                y: CGFloat(projection.y) * 20,
                depth: projection.z
            )
        }
        let origin = CGPoint(x: bounds.midX, y: bounds.midY)

        color.setStroke()
        for axis in axes.sorted(by: { $0.depth < $1.depth }) {
            let path = NSBezierPath()
            path.lineWidth = 1
            path.move(to: origin)
            path.line(to: CGPoint(x: origin.x + axis.x, y: origin.y + axis.y))
            path.stroke()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: color,
        ]
        var occupiedLabelFrames: [NSRect] = []
        for axis in axes.sorted(by: { $0.depth < $1.depth }) {
            let endpoint = CGPoint(x: origin.x + axis.x, y: origin.y + axis.y)
            let projectedLength = hypot(axis.x, axis.y)
            let unitX = projectedLength > 0.001 ? axis.x / projectedLength : 0
            let unitY = projectedLength > 0.001 ? axis.y / projectedLength : 0
            let proposedCenter = CGPoint(
                x: endpoint.x + unitX * 7,
                y: endpoint.y + unitY * 7
            )
            let size = (axis.label as NSString).size(withAttributes: attributes)
            func clampedCenter(_ proposed: CGPoint) -> CGPoint {
                CGPoint(
                    x: min(max(proposed.x, bounds.minX + size.width / 2),
                           bounds.maxX - size.width / 2),
                    y: min(max(proposed.y, bounds.minY + size.height / 2),
                           bounds.maxY - size.height / 2)
                )
            }
            let baseCenter = clampedCenter(proposedCenter)
            var center = baseCenter
            var labelFrame = NSRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            )

            for attempt in 0..<4 where occupiedLabelFrames.contains(where: { $0.intersects(labelFrame) }) {
                let side: CGFloat = attempt.isMultiple(of: 2) ? 1 : -1
                let offset = CGFloat(attempt / 2 + 1) * 4 * side
                center = clampedCenter(CGPoint(
                    x: baseCenter.x - unitY * offset,
                    y: baseCenter.y + unitX * offset
                ))
                labelFrame.origin = CGPoint(
                    x: center.x - size.width / 2,
                    y: center.y - size.height / 2
                )
            }

            occupiedLabelFrames.append(labelFrame)
            (axis.label as NSString).draw(in: labelFrame, withAttributes: attributes)
        }
    }
}
