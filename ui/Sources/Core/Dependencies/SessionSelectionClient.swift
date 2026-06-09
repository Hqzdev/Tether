import ComposableArchitecture
import Foundation

public struct SessionSelectionClient: Sendable {
    public var select: @Sendable (TraceSession.ID) async -> Void

    public init(select: @escaping @Sendable (TraceSession.ID) async -> Void) {
        self.select = select
    }
}

extension SessionSelectionClient: DependencyKey {
    public static let liveValue = Self { _ in }
    public static let testValue = Self { _ in }
}

public extension DependencyValues {
    var sessionSelectionClient: SessionSelectionClient {
        get { self[SessionSelectionClient.self] }
        set { self[SessionSelectionClient.self] = newValue }
    }
}
