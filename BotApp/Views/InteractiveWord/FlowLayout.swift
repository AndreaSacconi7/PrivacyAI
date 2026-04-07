import SwiftUI

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 4 // Spazio tra una parola e l'altra

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 300, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + result.frames[index].minX,
                                y: bounds.minY + result.frames[index].minY)
            subview.place(at: point, proposal: ProposedViewSize(result.frames[index].size))
        }
    }

    // Motore interno per calcolare dove posizionare le parole
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Layout.Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            // 👇 1. Creiamo una variabile per memorizzare la LARGHEZZA REALE
            var maxUsedWidth: CGFloat = 0

            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                // Se la parola sfora la larghezza massima, mandiamo a capo
                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: subviewSize.width, height: subviewSize.height))
                
                // 👇 2. Salviamo il punto più a destra raggiunto dalla parola
                let rightEdge = currentX + subviewSize.width
                maxUsedWidth = max(maxUsedWidth, rightEdge)
                
                currentX += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
            }
            
            // 👇 3. RESTITUIAMO LA LARGHEZZA REALE invece di maxWidth!
            size = CGSize(width: maxUsedWidth, height: currentY + lineHeight)
        }
    }
}
