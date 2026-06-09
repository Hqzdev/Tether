import ComposableArchitecture
import Foundation

@Reducer
public struct SessionListFeature: Sendable {
    @Dependency(\.sessionSelectionClient) var sessionSelectionClient

    @ObservableState
    public struct State: Equatable, Sendable {
        public struct Row: Equatable, Identifiable, Sendable {
            public let session: TraceSession
            public let selected: Bool
            public let live: Bool

            public var id: TraceSession.ID {
                session.id
            }
        }

        public var sessions: [TraceSession]
        public var selectedSessionId: TraceSession.ID?
        public var liveSessionId: TraceSession.ID?

        public init(
            sessions: [TraceSession] = [],
            selectedSessionId: TraceSession.ID? = nil,
            liveSessionId: TraceSession.ID? = nil
        ) {
            self.sessions = sessions
            self.selectedSessionId = selectedSessionId
            self.liveSessionId = liveSessionId
        }

        public var countText: String {
            sessions.isEmpty ? "0" : "\(sessions.count)"
        }

        public var isEmpty: Bool {
            sessions.isEmpty
        }

        public var rows: [Row] {
            sessions.map { session in
                Row(
                    session: session,
                    selected: session.id == selectedSessionId,
                    live: session.id == liveSessionId
                )
            }
        }
    }

    public enum Action: Equatable, Sendable {
        case sessionTapped(TraceSession.ID)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .sessionTapped(sessionId):
                guard state.sessions.contains(where: { $0.id == sessionId }) else {
                    return .none
                }

                state.selectedSessionId = sessionId
                return .run { [sessionSelectionClient, sessionId] _ in
                    await sessionSelectionClient.select(sessionId)
                }
            }
        }
    }
}
