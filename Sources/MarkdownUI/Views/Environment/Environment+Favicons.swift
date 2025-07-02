import SwiftUI

/// A struct that describes the ways to render favicons for the Markdown links in a view hierarchy.
/// - Parameter placeholder: The placeholder text to use for the favicons.
/// - Parameter cached: The cached favicons.
/// - Parameter fetch: The fetch function to use for the favicons.
public struct Favicons {
    public let placeholder: Text
    public let cached: (String) -> Text?
    public let fetch: (String) async -> Text?

    public init(
        placeholder: Text,
        cached: @escaping (String) -> Text?,
        fetch: @escaping (String) async -> Text?
    ) {
        self.placeholder = placeholder
        self.cached = cached
        self.fetch = fetch
    }
}

extension View {
    /// Sets the favicons renderer for the Markdown links in a view hierarchy.
    /// - Parameter favicons: The favicons to set.
    /// - Returns: A view that uses the specified favicons for itself and its child views.
    public func markdownFavicons(_ favicons: Favicons) -> some View {
        self.environment(\.favicons, favicons)
    }
}

extension EnvironmentValues {
    var favicons: Favicons? {
        get { self[FaviconsKey.self] }
        set { self[FaviconsKey.self] = newValue }
    }
}

private struct FaviconsKey: EnvironmentKey {
    static let defaultValue: Favicons? = nil
}
