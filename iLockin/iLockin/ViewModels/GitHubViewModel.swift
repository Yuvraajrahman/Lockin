import Foundation
import SwiftData
import OSLog

@MainActor
final class GitHubViewModel: ObservableObject {
    private let log = Logger(subsystem: "com.rogue.ilockin", category: "GitHubVM")

    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?
    @Published private(set) var hasToken: Bool = KeychainService.getGithubToken()?.isEmpty == false

    /// Refresh the cache if older than 24h, or force a fresh fetch.
    func refreshIfNeeded(context: ModelContext, settings: AppSettings, force: Bool = false) async {
        if !force, let last = settings.lastGithubFetchAt, Date().timeIntervalSince(last) < 24 * 3600 {
            return
        }
        await refresh(context: context, settings: settings)
    }

    func refresh(context: ModelContext, settings: AppSettings) async {
        isRefreshing = true
        defer { isRefreshing = false }

        let token = KeychainService.getGithubToken()
        hasToken = token?.isEmpty == false

        if (token == nil || token?.isEmpty == true) && settings.githubUsername.isEmpty {
            lastError = "Add a GitHub Personal Access Token (or username) in Settings."
            return
        }

        do {
            let repos = try await GitHubService.fetchRepos(token: token, username: settings.githubUsername)
            // Keep top 5 non-archived non-fork repos by recent push.
            let top = repos
                .filter { !$0.archived && !$0.fork }
                .prefix(5)

            // Replace cached repos.
            let existing = (try? context.fetch(FetchDescriptor<GitHubRepo>())) ?? []
            for old in existing { context.delete(old) }

            // Replace cached issues.
            let existingIssues = (try? context.fetch(FetchDescriptor<GitHubIssue>())) ?? []
            for old in existingIssues { context.delete(old) }

            for (idx, dto) in top.enumerated() {
                let commit = try? await GitHubService.fetchLatestCommit(
                    token: token,
                    fullName: dto.full_name,
                    branch: dto.default_branch
                )
                let repo = GitHubRepo(
                    id: dto.id,
                    name: dto.name,
                    fullName: dto.full_name,
                    repoDescription: dto.description ?? "",
                    url: dto.html_url,
                    lastCommitMessage: commit?.commit.message.firstLine ?? "",
                    lastCommitDate: commit?.commit.author?.date ?? dto.pushed_at,
                    lastCommitSHA: commit?.sha ?? "",
                    openIssuesCount: dto.open_issues_count,
                    stargazersCount: dto.stargazers_count,
                    defaultBranch: dto.default_branch,
                    fetchedAt: .now,
                    sortOrder: idx
                )
                context.insert(repo)

                let issues = (try? await GitHubService.fetchOpenIssues(token: token, fullName: dto.full_name, perPage: 3)) ?? []
                for issue in issues {
                    context.insert(GitHubIssue(
                        id: issue.id,
                        repoFullName: dto.full_name,
                        title: issue.title,
                        number: issue.number,
                        url: issue.html_url,
                        updatedAt: issue.updated_at
                    ))
                }
            }

            settings.lastGithubFetchAt = .now
            try? context.save()
            lastError = nil
        } catch GitHubService.GHError.notAuthenticated {
            lastError = "GitHub token missing. Add it in Settings."
        } catch GitHubService.GHError.http(let code) {
            lastError = "GitHub HTTP \(code). Check token scopes / username."
        } catch {
            lastError = error.localizedDescription
            log.error("GitHub refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private extension String {
    var firstLine: String {
        split(whereSeparator: \.isNewline).first.map(String.init) ?? self
    }
}
