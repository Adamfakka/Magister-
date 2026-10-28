import SwiftUI
import Foundation

/// Shared circular avatar for Mijn gegevens and the navigation drawer.
struct SchoolProfileAvatar: View {
    let url: String?
    let size: CGFloat

    private var imageURL: URL? {
        guard let url, let parsed = URL(string: url), parsed.scheme == "https", parsed.host != nil else { return nil }
        return parsed
    }

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        placeholder.overlay { ProgressView().tint(SchoolTheme.blue) }
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(imageURL == nil ? "Standaard profielafbeelding" : "Profielfoto")
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(SchoolTheme.ink.opacity(0.65))
            .frame(width: size, height: size)
    }
}
