import Foundation
import OSLog

/// Lightweight GitHub REST v3 client. Uses a Personal Access Token if supplied
/// (read from Keychain by callers). All endpoints we hit are read-only.
enum GitHubService {
    private static let log = Logger(subsystem: "com.rogue.ilockin", category: "GitHubService")
    private static let base = URL(string: "https://api.github.com")!

    enum GHError: Error {
        case notAuthenticated
        case http(Int)
        case decoding
    }

    // MARK: - DTOs

    struct RepoDTO: Decodable {
        let id: Int
        let name: String
        let full_name: String
        let description: String?
        let html_url: String
        let open_issues_count: Int
        let stargazers_count: Int
        let default_branch: String
        let pushed_at: Date?
        let fork: Bool
        let archived: Bool
    }

    struct CommitDTO: Decodable {
        struct Commit: Decodable {
            struct Author: Decodable { let date: Date? }
            let message: String
            let author: Author?
        }
        let sha: String
        let commit: Commit
    }

    struct IssueDTO: Decodable {
        let id: Int
        let number: Int
        let title: String
        let html_url: String
        let updated_at: Date
        let pull_request: PR?
        struct PR: Decodable {}
    }

    // MARK: - Public

    /// Fetch the authenticated user's repos sorted by recent push.
    /// If `username` is non-empty, falls back to the public user endpoint.
    static func fetchRepos(token: String?, username: String) async throws -> [RepoDTO] {
        let url: URL
        if !username.isEmpty {
            url = base.appendingPathComponent("users/\(username)/repos")
                .appendingQuery([
                    "per_page": "30",
                    "sort": "pushed",
                    "direction": "desc"
                ])
        } else {
            guard token != nil else { throw GHError.notAuthenticated }
            url = base.appendingPathComponent("user/repos")
                .appendingQuery([
                    "per_page": "30",
                    "sort": "pushed",
                    "direction": "desc",
                    "affiliation": "owner,collaborator"
                ])
        }

        let data = try await get(url: url, token: token)
        let decoder = jsonDecoder()
        do {
            return try decoder.decode([RepoDTO].self, from: data)
        } catch {
            log.error("Repo decode failed: \(error.localizedDescription, privacy: .public)")
            throw GHError.decoding
        }
    }

    /// Fetch the latest commit on the default branch for a repo.
    static func fetchLatestCommit(token: String?, fullName: String, branch: String) async throws -> CommitDTO? {
        let url = base.appendingPathComponent("repos/\(fullName)/commits")
            .appendingQuery(["sha": branch, "per_page": "1"])
        let data = try await get(url: url, token: token)
        let decoder = jsonDecoder()
        do {
            return try decoder.decode([CommitDTO].self, from: data).first
        } catch {
            log.error("Commit decode failed for \(fullName, privacy: .public)")
            return nil
        }
    }

    /// Fetch up to `perPage` open issues (excluding pull requests) for a repo.
    static func fetchOpenIssues(token: String?, fullName: String, perPage: Int = 5) async throws -> [IssueDTO] {
        let url = base.appendingPathComponent("repos/\(fullName)/issues")
            .appendingQuery([
                "state": "open",
                "per_page": String(perPage),
                "sort": "updated",
                "direction": "desc"
            ])
        let data = try await get(url: url, token: token)
        let decoder = jsonDecoder()
        let all = (try? decoder.decode([IssueDTO].self, from: data)) ?? []
        return all.filter { $0.pull_request == nil }
    }

    // MARK: - Internals

    private static func get(url: URL, token: String?, session: URLSession = .shared) async throws -> Data {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.setValue("iLockin/0.1", forHTTPHeaderField: "User-Agent")
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            log.error("GitHub HTTP \(http.statusCode) for \(url.absoluteString, privacy: .public)")
            throw GHError.http(http.statusCode)
        }
        return data
    }

    private static func jsonDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let s = try container.decode(String.self)
            if let date = iso.date(from: s) { return date }
            // Fallback for fractional-second variants.
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad ISO date: \(s)")
        }
        return d
    }
}

private extension URL {
    func appendingQuery(_ items: [String: String]) -> URL {
        var c = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        c.queryItems = (c.queryItems ?? []) + items.map { URLQueryItem(name: $0.key, value: $0.value) }
        return c.url ?? self
    }
}
