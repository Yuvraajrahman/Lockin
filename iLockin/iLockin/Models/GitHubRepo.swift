import Foundation
import SwiftData

/// Cached snapshot of one of the user's GitHub repositories.
/// We persist a small, dashboard-shaped subset so the app works offline.
@Model
final class GitHubRepo {
    /// GitHub numeric repo id – stable, used as the unique key.
    @Attribute(.unique) var id: Int
    var name: String
    var fullName: String
    var repoDescription: String
    var url: String
    var lastCommitMessage: String
    var lastCommitDate: Date?
    var lastCommitSHA: String
    var openIssuesCount: Int
    var stargazersCount: Int
    var defaultBranch: String
    var fetchedAt: Date
    /// Lower = appears first on dashboard.
    var sortOrder: Int

    init(
        id: Int,
        name: String,
        fullName: String,
        repoDescription: String = "",
        url: String,
        lastCommitMessage: String = "",
        lastCommitDate: Date? = nil,
        lastCommitSHA: String = "",
        openIssuesCount: Int = 0,
        stargazersCount: Int = 0,
        defaultBranch: String = "main",
        fetchedAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.repoDescription = repoDescription
        self.url = url
        self.lastCommitMessage = lastCommitMessage
        self.lastCommitDate = lastCommitDate
        self.lastCommitSHA = lastCommitSHA
        self.openIssuesCount = openIssuesCount
        self.stargazersCount = stargazersCount
        self.defaultBranch = defaultBranch
        self.fetchedAt = fetchedAt
        self.sortOrder = sortOrder
    }
}

/// Lightweight cached open-issue summary used as "Next tasks today".
@Model
final class GitHubIssue {
    @Attribute(.unique) var id: Int
    var repoFullName: String
    var title: String
    var number: Int
    var url: String
    var updatedAt: Date

    init(id: Int, repoFullName: String, title: String, number: Int, url: String, updatedAt: Date = .now) {
        self.id = id
        self.repoFullName = repoFullName
        self.title = title
        self.number = number
        self.url = url
        self.updatedAt = updatedAt
    }
}
