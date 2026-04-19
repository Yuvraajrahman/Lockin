import SwiftUI
import SwiftData
import AppKit

/// Right-column dashboard panel: active repos + open issues ("Next tasks").
struct GitHubPanelView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var github: GitHubViewModel
    @Query(sort: \GitHubRepo.sortOrder) private var repos: [GitHubRepo]
    @Query(sort: \GitHubIssue.updatedAt, order: .reverse) private var issues: [GitHubIssue]

    var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                ILSectionTitle(text: "GitHub", glyph: "chevron.left.forwardslash.chevron.right")
                Button(action: refresh) {
                    Image(systemName: github.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Theme.orange)
                        .rotationEffect(.degrees(github.isRefreshing ? 360 : 0))
                        .animation(github.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                   value: github.isRefreshing)
                }
                .buttonStyle(.plain)
                .disabled(github.isRefreshing)
            }

            if let err = github.lastError {
                ILCard {
                    Text(err)
                        .font(Theme.displayFont(12, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    // Active repos.
                    VStack(spacing: 10) {
                        ForEach(repos) { repo in
                            RepoCard(repo: repo)
                        }
                        if repos.isEmpty {
                            ILCard {
                                Text("No repos cached yet. Tap refresh after adding your token in Settings.")
                                    .font(Theme.displayFont(12, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }

                    // Progress overview.
                    OverviewCard(repos: repos, issues: issues)

                    // Next tasks today (open issues).
                    VStack(alignment: .leading, spacing: 10) {
                        ILSectionTitle(text: "Next Tasks Today", glyph: "checklist")
                        if issues.isEmpty {
                            ILCard {
                                Text("No open issues across your top repos.")
                                    .font(Theme.displayFont(12, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        } else {
                            ForEach(issues.prefix(8)) { issue in
                                IssueRow(issue: issue)
                            }
                        }
                    }
                }
            }
        }
    }

    private func refresh() {
        Task { await github.refresh(context: context, settings: settings) }
    }
}

// MARK: - Repo card

private struct RepoCard: View {
    let repo: GitHubRepo

    var body: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(repo.name)
                        .font(Theme.displayFont(15, weight: .black))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        if let url = URL(string: repo.url) { NSWorkspace.shared.open(url) }
                    } label: {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(Theme.orange)
                    }
                    .buttonStyle(.plain)
                }
                if !repo.repoDescription.isEmpty {
                    Text(repo.repoDescription)
                        .font(Theme.displayFont(11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                if !repo.lastCommitMessage.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Theme.orange)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(repo.lastCommitMessage)
                                .font(Theme.displayFont(12, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2)
                            if let date = repo.lastCommitDate {
                                Text(date.formatted(.relative(presentation: .named)))
                                    .font(Theme.monoFont(10))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                HStack(spacing: 14) {
                    Label("\(repo.openIssuesCount)", systemImage: "exclamationmark.circle")
                    Label("\(repo.stargazersCount)", systemImage: "star.fill")
                    Text(repo.defaultBranch)
                }
                .font(Theme.monoFont(10))
                .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

private struct OverviewCard: View {
    let repos: [GitHubRepo]
    let issues: [GitHubIssue]

    var body: some View {
        ILCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("OVERVIEW")
                    .font(Theme.displayFont(11, weight: .black))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 18) {
                    Stat(value: "\(repos.count)", label: "Active Repos")
                    Stat(value: "\(issues.count)", label: "Open Issues")
                    Stat(value: "\(repos.reduce(0) { $0 + $1.stargazersCount })", label: "Total Stars")
                }
            }
        }
    }

    private struct Stat: View {
        let value: String
        let label: String
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(Theme.displayFont(22, weight: .black))
                    .foregroundStyle(Theme.orange)
                Text(label.uppercased())
                    .font(Theme.displayFont(9, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

private struct IssueRow: View {
    let issue: GitHubIssue
    var body: some View {
        Button {
            if let url = URL(string: issue.url) { NSWorkspace.shared.open(url) }
        } label: {
            ILCard(padding: 12) {
                HStack(alignment: .top, spacing: 10) {
                    ILGlyph(name: "circle.dashed", size: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.title)
                            .font(Theme.displayFont(12, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(2)
                        Text("\(issue.repoFullName) #\(issue.number)")
                            .font(Theme.monoFont(10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
}
