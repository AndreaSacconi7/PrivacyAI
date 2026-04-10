import SwiftUI

@available(iOS 16.0, *)
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    // 1. CREIAMO LA CACHE: La memoria dove salveremo i calcoli per non ripeterli
    struct CacheData {
        var size: CGSize
        var frames: [CGRect]
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData(size: .zero, frames: [])
    }

    // 2. PRIMO STEP: SwiftUI chiede le dimensioni. Noi calcoliamo TUTTO e lo salviamo nella cache.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        // Prendiamo la larghezza proposta, se non c'è usiamo lo schermo
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width
        
        // Eseguiamo il motore matematico UNA SOLA VOLTA e salviamo il risultato in "cache"
        cache = calculateFrames(maxWidth: maxWidth, subviews: subviews)
        
        return cache.size
    }

    // 3. SECONDO STEP: SwiftUI ci dice di disegnare. Noi piazziamo le parole usando la cache!
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        for (index, subview) in subviews.enumerated() {
            if index < cache.frames.count {
                let frame = cache.frames[index]
                
                // Calcoliamo il punto esatto basandoci SOLO sui dati salvati
                let point = CGPoint(
                    x: bounds.minX + frame.minX,
                    y: bounds.minY + frame.minY
                )
                
                // Piazziamo la parola dandole la sua dimensione naturale
                subview.place(at: point, proposal: .unspecified)
            }
        }
    }

    // MARK: - Il tuo Motore Matematico (Isolato e Sicuro)
    private func calculateFrames(maxWidth: CGFloat, subviews: Subviews) -> CacheData {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxUsedWidth: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            // Chiediamo alla parola la sua grandezza naturale
            let subviewSize = subview.sizeThatFits(.unspecified)

            // Se la parola è troppo lunga per questa riga, a capo!
            if currentX + subviewSize.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            // Salviamo il rettangolo esatto per questa parola
            frames.append(CGRect(x: currentX, y: currentY, width: subviewSize.width, height: subviewSize.height))

            // Aggiorniamo i contatori
            let rightEdge = currentX + subviewSize.width
            maxUsedWidth = max(maxUsedWidth, rightEdge)

            currentX += subviewSize.width + spacing
            lineHeight = max(lineHeight, subviewSize.height)
        }

        let totalSize = CGSize(width: maxUsedWidth, height: currentY + lineHeight)
        return CacheData(size: totalSize, frames: frames)
    }
}
