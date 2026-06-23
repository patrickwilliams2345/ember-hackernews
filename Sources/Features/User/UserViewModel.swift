import Foundation
import Observation

@MainActor
@Observable
final class UserViewModel {
    let username: String
    private(set) var user: HNUser?
    private(set) var submissions: [HNItem] = []
    private(set) var comments: [UserComment] = []
    private(set) var phase: LoadPhase = .loading

    private let service: HNServicing

    init(username: String, service: HNServicing = LiveHNService.shared) {
        self.username = username
        self.service = service
    }

    func load() async {
        guard user == nil else { return }
        do {
            let fetched = try await service.user(username)
            user = fetched
            let ids = Array((fetched.submitted ?? []).prefix(20))
            // Profile, submissions and comments are independent — fetch in parallel.
            async let submissionItems: [HNItem] = ids.isEmpty ? [] : service.items(ids)
            async let recentComments = (try? service.comments(byAuthor: username, limit: 30)) ?? []
            // Keep only top-level submissions (stories/jobs/polls), not comments.
            submissions = (try await submissionItems).filter { $0.title != nil }
            comments = await recentComments
            phase = .loaded
        } catch {
            phase = .failed((error as? HNError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
