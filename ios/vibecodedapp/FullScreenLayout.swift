import SwiftUI

// Games and other full-screen apps place their controls with this instead of the safe area: on iPhone Duo the
// safe area gives up a whole strip along one display edge although the camera and status bar fill only its top.
struct FullScreenLayout<Content: View>: View {
    @ViewBuilder var content: (ReservedRegions) -> Content

    var body: some View {
        // reservedRegions ships in the iOS 27.1 SDK (SwiftUI 8.0.85); builds on Xcode 27.0 compile the fallback.
        #if canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            GeometryReader { proxy in
                let occlusions = proxy.reservedRegions(kind: .occlusion).map(\.frame)
                let divisions = proxy.reservedRegions(kind: .division).map(\.frame)
                content(ReservedRegions(size: proxy.size, frames: occlusions + divisions))
            }
            .coordinateSpace(.named(ReservedRegions.space))
            .ignoresSafeArea(edges: .horizontal)
        } else {
            safeAreaLayout
        }
        #else
        safeAreaLayout
        #endif
    }

    private var safeAreaLayout: some View {
        GeometryReader { proxy in content(ReservedRegions(size: proxy.size, frames: [])) }
            .coordinateSpace(.named(ReservedRegions.space))
    }
}

extension View {
    /// Keeps this control or bar clear of the camera and status bar on the display's edges, measuring where it
    /// actually sits: it moves in only beside them and reaches the edge everywhere else.
    func clearOfReservedRegions(_ reserved: ReservedRegions) -> some View {
        modifier(ClearOfReservedRegions(reserved: reserved))
    }
}

private struct ClearOfReservedRegions: ViewModifier {
    let reserved: ReservedRegions
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var measured: Measured?

    // nonisolated: the project defaults to MainActor isolation, and onGeometryChange needs a Sendable value.
    nonisolated private struct Measured: Equatable, Sendable {
        var regions: [CGRect]
        var rows: ClosedRange<CGFloat>
    }

    func body(content: Content) -> some View {
        let rows = measured?.regions == reserved.frames ? measured?.rows : nil
        let left = rows.map { reserved.leadingInset(for: $0) } ?? 0
        let right = rows.map { reserved.trailingInset(for: $0) } ?? 0
        let rightToLeft = layoutDirection == .rightToLeft
        content
            .onGeometryChange(for: Measured.self) { proxy in
                let frame = proxy.frame(in: .named(ReservedRegions.space))
                return Measured(regions: reserved.frames, rows: frame.minY...max(frame.minY, frame.maxY))
            } action: { new in
                // A height change with one edge fixed is the padding re-wrapping the control: keep the larger rows
                // so it cannot oscillate. A move (both edges shift) or new regions start over.
                if let old = measured, old.regions == new.regions,
                   abs(old.rows.lowerBound - new.rows.lowerBound) < 0.5
                    || abs(old.rows.upperBound - new.rows.upperBound) < 0.5 {
                    let top = min(old.rows.lowerBound, new.rows.lowerBound)
                    let bottom = max(old.rows.upperBound, new.rows.upperBound)
                    measured = Measured(regions: new.regions, rows: top...bottom)
                } else {
                    measured = new
                }
            }
            // The insets are physical left and right; leading and trailing swap in right-to-left layouts.
            .padding(.leading, rightToLeft ? right : left)
            .padding(.trailing, rightToLeft ? left : right)
    }
}

/// The camera, status bar and (while an iPhone Duo is half open) hinge, in the layout's coordinates.
struct ReservedRegions {
    static let space = "FullScreenLayout"

    let size: CGSize
    let frames: [CGRect]

    /// How far a control spanning `rows` must stay from the trailing edge to clear the regions on that edge.
    func trailingInset(for rows: ClosedRange<CGFloat>) -> CGFloat {
        edgeRegions(in: rows).filter { $0.maxX >= size.width - 1 }.map { size.width - $0.minX }.max() ?? 0
    }

    /// How far a control spanning `rows` must stay from the leading edge to clear the regions on that edge.
    func leadingInset(for rows: ClosedRange<CGFloat>) -> CGFloat {
        edgeRegions(in: rows).filter { $0.minX <= 1 }.map(\.maxX).max() ?? 0
    }

    /// Rows taken by a region spanning the full width (the hinge of a Duo propped open like a laptop):
    /// keep controls above or below them.
    var blockedRows: [ClosedRange<CGFloat>] {
        frames.filter { $0.width >= size.width - 1 }.map { $0.minY...$0.maxY }
    }

    private func edgeRegions(in rows: ClosedRange<CGFloat>) -> [CGRect] {
        frames.filter { $0.minY < rows.upperBound && $0.maxY > rows.lowerBound && $0.width < size.width - 1 }
    }
}
