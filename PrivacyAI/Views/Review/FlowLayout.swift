import SwiftUI

/// Lays out subviews left to right, wrapping onto a new line when the
/// current one is full, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    struct Cache {
        var size: CGSize = .zero
        var frames: [CGRect] = []
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        // Measure once here and reuse the frames in `placeSubviews`.
        cache = computeFrames(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        return cache.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        for (subview, frame) in zip(subviews, cache.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func computeFrames(maxWidth: CGFloat, subviews: Subviews) -> Cache {
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: origin, size: size))
            usedWidth = max(usedWidth, origin.x + size.width)
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return Cache(size: CGSize(width: usedWidth, height: origin.y + lineHeight), frames: frames)
    }
}
