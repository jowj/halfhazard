//
//  MigrationHarness.swift
//  halfhazardTests
//

import XCTest
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
@testable import halfhazard

/// Runs the migration against the real database.
///
/// This is the thing that decides whether the ledger is safe to cut over to, so it lives
/// where it can be run on demand rather than behind a screen that phase 5 deletes anyway.
/// It skips itself unless it is configured, so it never runs as part of an ordinary test pass.
///
/// Drive it with `./scripts/migrate.sh dry-run|commit|audit`.
///
/// Configuration comes from a `.migration-env` file in the repo root rather than from the
/// environment, because `xcodebuild test` does not pass its environment through to the test
/// process. Exported variables simply do not arrive — the harness skipped, and a skipped
/// test reports success, so a migration that never ran looked exactly like one that worked.
/// The file is found relative to this source file, so it works whatever the working
/// directory is. It is gitignored; it holds a password. (Reading it is allowed under the app
/// sandbox; writing back to the repo is not, which is why the report is an attachment.)
///
///     HALFHAZARD_MIGRATION_HARNESS=1
///     HALFHAZARD_EMAIL=you@example.com
///     HALFHAZARD_PASSWORD=…
///
final class MigrationHarness: XCTestCase {

    // MARK: - Configuration

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // halfhazardTests
        .deletingLastPathComponent()  // repo root

    /// `.migration-env`, parsed as `KEY=VALUE` lines. A real environment variable still wins
    /// if one somehow arrives, so nothing here blocks running it by hand.
    private static let configuration: [String: String] = {
        let file = repoRoot.appendingPathComponent(".migration-env")
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return [:] }

        var values: [String: String] = [:]
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                  let separator = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            values[key] = value
        }
        return values
    }()

    private func setting(_ key: String) -> String? {
        let fromEnvironment = ProcessInfo.processInfo.environment[key]
        return (fromEnvironment?.isEmpty == false) ? fromEnvironment : Self.configuration[key]
    }

    /// Marker files the script writes just before a run and deletes straight after, so
    /// running the harness class by hand cannot write to the database by accident.
    private func marker(_ name: String) -> String? {
        try? String(contentsOf: Self.repoRoot.appendingPathComponent(name), encoding: .utf8)
    }

    private var commitWasRequested: Bool {
        marker(".migration-commit") != nil || setting("HALFHAZARD_MIGRATION_COMMIT") == "1"
    }

    /// Commit anyway, despite blocking issues. Set only after reading what they are.
    private var forceWasRequested: Bool {
        marker(".migration-force") != nil
    }

    /// Expense ids to dump, one per line.
    private var idsToInspect: [String] {
        list(marker(".migration-inspect") ?? "")
    }

    private func list(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// What to migrate.
    ///
    /// Without `HALFHAZARD_MIGRATION_GROUPS`, every group becomes its own ledger — fine for
    /// looking around, wrong as a destination, since the single-screen UI shows one ledger
    /// and this account has four groups, two of them scratch. Name the groups to fold into
    /// one ledger, and optionally the id that ledger should have:
    ///
    ///     HALFHAZARD_MIGRATION_GROUPS=WwQYJYtRPYpAVV6koJtO,UN1XTtybeNtnHWgRTE50
    ///     HALFHAZARD_MIGRATION_LEDGER_ID=WwQYJYtRPYpAVV6koJtO
    private func targets(_ service: MigrationService) async throws -> [MigrationService.Target] {
        let chosen = list(setting("HALFHAZARD_MIGRATION_GROUPS") ?? "")
        guard !chosen.isEmpty else {
            return try await service.allGroupsAsSeparateLedgers()
        }
        return [MigrationService.Target(
            ledgerId: setting("HALFHAZARD_MIGRATION_LEDGER_ID"),
            groupIds: chosen
        )]
    }

    // MARK: - Reporting

    private var reportLines: [String] = []

    /// Collects a line for the report.
    ///
    /// The report comes out as a test attachment, which is the only channel that survives
    /// the trip: `print` from an app-hosted unit test never reaches xcodebuild's output, and
    /// the app is sandboxed, so the test process cannot write a file into the repo either.
    /// `scripts/migrate.sh` pulls the attachment back out of the result bundle.
    private func report(_ text: String) {
        reportLines.append(contentsOf: text.components(separatedBy: "\n"))
    }

    /// Routes failures into the report too. Xcode keeps the detail of a failed assertion in
    /// the result bundle, so without this the terminal says only that something failed.
    override func record(_ issue: XCTIssue) {
        report("FAILURE: \(issue.compactDescription)")
        super.record(issue)
    }

    override func tearDown() {
        if !reportLines.isEmpty {
            let attachment = XCTAttachment(string: reportLines.joined(separator: "\n"))
            attachment.name = "migration-report"
            attachment.lifetime = .keepAlways
            add(attachment)
            reportLines = []
        }
        super.tearDown()
    }

    override func setUp() async throws {
        try XCTSkipUnless(
            setting("HALFHAZARD_MIGRATION_HARNESS") == "1",
            "Add HALFHAZARD_MIGRATION_HARNESS=1 to .migration-env in the repo root to run this."
        )

        // Past this point the harness was asked for, so missing credentials are a failure
        // rather than another quiet skip.
        guard let email = setting("HALFHAZARD_EMAIL"), let password = setting("HALFHAZARD_PASSWORD") else {
            XCTFail("HALFHAZARD_EMAIL and HALFHAZARD_PASSWORD must be set in .migration-env.")
            return
        }

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()

            // The test host is the app, so it shares the app's sandbox container and, with
            // it, Firestore's on-disk cache. If halfhazard is open, its leveldb lock makes
            // this process abort during launch — before any test runs, which reads as an
            // unexplained bootstrap crash. Keeping the cache in memory sidesteps the lock
            // entirely, and a migration has no use for a warm cache anyway.
            let settings = Firestore.firestore().settings
            settings.cacheSettings = MemoryCacheSettings()
            Firestore.firestore().settings = settings
        }
        if Auth.auth().currentUser == nil {
            try await Auth.auth().signIn(withEmail: email, password: password)
        }
        report("signed in as \(Auth.auth().currentUser?.email ?? "?")")
    }

    /// Reads every group the signed-in user belongs to and prints what migrating it would do.
    /// Fails if any group would not migrate cleanly, so a red run means "read the report".
    func testDryRun() async throws {
        let service = MigrationService()
        let targets = try await targets(service)
        XCTAssertFalse(targets.isEmpty, "No groups found for this account.")

        for target in targets {
            let migration = try await service.dryRun(target: target)
            report(migration.summary)
            XCTAssertTrue(migration.isClean, "Group \(migration.plan.ledgerId) would not migrate cleanly.")
        }
    }

    /// Writes the entries, and still refuses anything the dry run did not bless. Audits what
    /// it wrote before returning, so a green run means the entries are really there and the
    /// balances really match.
    func testCommit() async throws {
        try XCTSkipUnless(commitWasRequested, "Run ./scripts/migrate.sh commit to write entries.")

        let service = MigrationService()
        let targets = try await targets(service)
        XCTAssertFalse(targets.isEmpty, "No groups found for this account.")

        if forceWasRequested {
            report("FORCED: committing despite blocking issues.")
        }

        for target in targets {
            let migration = try await service.dryRun(target: target)
            report(migration.summary)
            if forceWasRequested && !migration.isClean {
                // The summary above ends with "do not commit", which reads alarmingly next
                // to a commit that then goes ahead.
                report("(forced — committing despite the above)")
            }
            let written = try await service.commit(report: migration, force: forceWasRequested)
            report("wrote \(written) entries for ledger \(migration.plan.ledgerId)")
        }

        for target in targets {
            let audit = try await service.audit(target: target)
            report(audit.summary)
            XCTAssertTrue(audit.isComplete, "Ledger \(audit.plan.ledgerId) did not come back complete.")
        }
    }

    /// Dumps the legacy documents named in `.migration-inspect`, as stored and as migrated.
    /// For working out what to do about something the dry run flagged.
    func testInspect() async throws {
        let ids = idsToInspect
        try XCTSkipUnless(!ids.isEmpty, "Run ./scripts/migrate.sh inspect <expense-id> …")

        let service = MigrationService()
        for id in ids {
            report(try await service.inspect(expenseId: id))
        }
    }

    /// Runs the real store against the real database and reports what the screen would show.
    /// For diagnosing "the app shows an error and nothing else" without guessing.
    @MainActor
    func testLiveStore() async throws {
        let viewerId = try XCTUnwrap(Auth.auth().currentUser?.uid)
        let service = FirestoreLedgerService()

        // Each read separately, so the report says which one is refused rather than just
        // that something was.
        do {
            let ledger = try await service.ledger(for: viewerId)
            report("ledger(for:): \(ledger?.id ?? "none") members \(ledger?.memberIds.joined(separator: ", ") ?? "-")")

            if let ledger {
                do {
                    let users = try await service.users(ids: ledger.memberIds)
                    report("users(ids:): \(users.count) of \(ledger.memberIds.count)"
                        + " — \(users.map { $0.displayName ?? $0.email }.joined(separator: ", "))")
                } catch {
                    report("users(ids:) FAILED: \(error.localizedDescription)")
                }

                let entries = try await service.loadEntriesOnce(ledgerId: ledger.id)
                report("entries: \(entries.count)")
            }
        } catch {
            report("ledger(for:) FAILED: \(error.localizedDescription)")
        }

        let store = LedgerStore(source: service, viewerId: viewerId)
        await store.start()
        try await Task.sleep(nanoseconds: 3_000_000_000)
        report("store: ledger=\(store.ledger?.id ?? "none") entries=\(store.entries.count)"
            + " standing=\(store.standing.amount.formatted()) error=\(store.errorMessage ?? "none")")
        report("names: " + (store.ledger?.memberIds.map { "\($0)=\(store.name(for: $0))" }
            .joined(separator: ", ") ?? "-"))
    }

    /// Reads the database back and reports whether it holds what the migration should have
    /// written. Safe to run any time, including before a commit, where it will say that
    /// nothing has been written yet.
    func testAudit() async throws {
        let service = MigrationService()
        let targets = try await targets(service)
        XCTAssertFalse(targets.isEmpty, "No groups found for this account.")

        var audits: [MigrationAudit] = []
        for target in targets {
            let audit = try await service.audit(target: target)
            report(audit.summary)
            audits.append(audit)
        }
        XCTAssertTrue(audits.allSatisfy(\.isComplete), "The ledger does not match the old data.")
    }
}
