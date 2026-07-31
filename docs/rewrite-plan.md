# halfhazard rewrite: ledger model + single-screen UI

Working document for the in-progress rewrite. Started 2026-07-30 from commit `294a77f`.

## Why

The app is for exactly two people (Josiah and Laura) splitting expenses. The old model
was built for open-ended group membership that never happened, and grew several defects
that make the UI feel unreliable:

- `SplitType.currentUserOwes` / `.currentUserOwed` are **viewer-relative concepts stored
  persistently**. "Current user" means whoever created the expense, so every label and
  branch keyed off them reads backwards for the other person
  (`ExpenseRow.swift:189` labels a partner's expense "You Paid").
- **Two disagreeing balance calculations.** `GroupViewModel.swift:490` keys off
  `expense.createdBy` and ignores the `payments` map entirely; `ExpenseRow.swift:81-103`
  uses `payments` with a legacy fallback. Sidebar and rows could show different numbers.
- **Settlement is a boolean, not an event.** No way to record "Laura sent $47 on Mar 3".
  Partial settlement impossible; balances not auditable because the flag is reversible.
- **Derived data persisted in several places.** `splits` is recomputed from
  `customSplitPercentages × amount` in four separate spots, which is where the last
  three bugfix commits landed.
- `Double` money, no transaction date distinct from `createdAt`, no category.

## Decisions

| Question | Decision |
| --- | --- |
| Settlement | Append-only ledger entries, not `settled` flags |
| Scope | New model + new UI, migrate existing data |
| Platform | iOS primary; macOS shares the views |
| Groups | Dropped from the UI entirely |
| Navigation | Single screen: balance header, feed, add/settle sheets |

### Groups are gone

A membership document survives as `Ledger` purely so Firestore rules can answer "may
this user read this entry?". It is never shown. This deletes roughly 1,800 lines:
`GroupListView`, `CreateGroupForm`, `JoinGroupForm`, `ManageGroupSheet`,
`GroupViewModel`, most of `GroupService`, the Groups tab, the sidebar, every
"Select a Group" empty state, `User.groupIds`, and `Group.settled`.

Note the old "invite code" was just the group document ID (`GroupService.swift:132`),
so there is no real pairing system to preserve. Pairing stays as a hidden settings row.

## The model

Expenses and settlements share one shape, so balance has no per-kind branching:

```
Josiah pays $84.20 groceries, 50/50
  paidBy: [J: 84.20]   owedBy: [J: 42.10, L: 42.10]

Laura settles $42.10
  paidBy: [L: 42.10]   owedBy: [J: 42.10]

balance(u) = Σ over all entries of (paidBy[u] − owedBy[u])
```

`kind` only affects how a row is drawn. Invariants, both covered by tests:
every entry has `Σ paidBy == Σ owedBy == amount`, and member balances always sum to zero.

Money is integer cents. Split rules (`equal` / `percentage` / `exact` / `shares`) are
allocated by one pure function using largest-remainder distribution, so parts always sum
back to the total. `Double` input cannot represent every half-cent — 1.005 is held as
1.00499999999999989 — so user input goes through `Decimal`, and the `Double` initializer
exists only for reading legacy data.

## Migration rules

Reads `expenses`, writes **`ledgers/{id}/entries/{id}`**. Entries are a subcollection rather
than a top-level collection because of how Firestore authorizes queries: a rule that reads
`resource.data.ledgerId` can authorize fetching one entry but not querying for many, since
the query has to be authorized before any document is in hand. With the ledger id in the
path the same rule covers a get and a list. Never modifies existing data; the old collection
stays as a backup. Dry-run computes balances both ways and reports
mismatches before anything cuts over.

- `amount`: `Money(roundingDollars:)`
- `paidBy`: use `payments` when non-empty. When empty, resolve the legacy intent **once
  and store it permanently** rather than re-guessing on every render:
  - `.currentUserOwed`, `.equal`, `.custom` → creator paid the full amount
  - `.currentUserOwes` → **the other person paid**. The old migration
    (`ExpenseService.swift:94-97`) recorded no payment at all here, leaving those
    entries unbalanced. With two people the intent is unambiguous.
- `owedBy`: from `splits`, rescaled to cents with remainder correction so it sums to
  `amount` exactly
- `splitRule`: `.equal` when splits are even, otherwise `.exact`. Do not try to recover
  percentages
- `date`: the old `createdAt`
- Settled expenses keep their real numbers. Each distinct `settledAt` batch becomes one
  synthesized settlement entry that zeroes what that batch represented, preserving both
  history and current balance

## Phases

1. ~~Pure model + balance engine + allocator, fully tested, no Firebase~~ **done**
2. ~~Migration + dry-run verification harness~~ **done**
3. ~~`LedgerStore` on a Firestore snapshot listener, replacing the `NotificationCenter` bus~~ **done**
4. ~~Single-screen UI: balance header, feed, add/settle sheets~~ **done**
5. ~~Delete the group world, collapse the two root views~~ **done**
6. Port templates onto `SplitRule` ← next
7. Firestore rules + indexes for `entries`

### Phase 1 output

`Models/Money.swift`, `SplitRule.swift`, `LedgerEntry.swift`, `Balance.swift`,
`Ledger.swift`; 36 tests in `halfhazardTests/Models/LedgerTests.swift`. All passing,
build green, nothing deleted.

### Phase 2 output

`Migration/LedgerMigrator.swift` (pure: legacy documents in, a `MigrationPlan` out),
`Migration/MigrationReport.swift` (the dry run, plus `LegacyBalance` reproducing both old
calculations bug-for-bug), `Services/MigrationService.swift` (reads `expenses`, writes
`entries` and `ledgers`, never the old collections). 32 tests in
`halfhazardTests/Models/MigrationTests.swift`, plus `MigrationHarness.swift` for running it
against real data. `./run_tests.sh ledger` and `./run_tests.sh migration` run the two new
groups. Nothing deleted; migration is not wired into the app yet.

Entry ids are the legacy document ids and settlement ids are derived from their batch, so
re-running overwrites rather than duplicates.

The verification is per document, not per total. An expense whose `payments` map recorded a
payer must migrate to the cent, and any drift there names the document and blocks the commit.
Balances that move because a payer was *inferred* are reported as a correction with a figure
attached — on a total they would have cancelled each other out and looked fine.

`firestore.rules` now covers `ledgers` and `entries`, pulled forward from phase 7 because a
commit cannot happen without them. Entry access is decided by reading the ledger's
`memberIds`, so `MigrationService.commit` awaits the ledger write before committing entries —
the non-async `setData(from:)` returns once the write is queued locally, and the entry batch
could otherwise reach the server first and be denied. **The rules have to be deployed before
a commit will work.** Phase 7 still owns the indexes; the migration itself needs none, but
phase 3's feed query (`ledgerId` ascending, `date` descending) will.

Migrating a `.currentUserOwes` expense with no `payments` map changes both balances, on
purpose — the old app credited the money to nobody. The report prints the size of that
correction per person before anything is written.

### What the real data turned out to be

Four groups, and every balance in all of them is zero — the old data says the two of them are
completely settled up.

| Group | Members | Expenses | Activity |
| --- | --- | --- | --- |
| `WwQYJYtRPYpAVV6koJtO` | 2 | 21 | Dec 18 2025 – May 11 2026 — **the live one** |
| `UN1XTtybeNtnHWgRTE50` | 2 | 53 | Apr 18 2025 – Dec 18 2025 |
| `RoPAJh8PvaKhfJc0RnIr` | 1 | 3 | scratch ("does it work if there's no one else?") |
| `ZST1RMpy9XRukEsOQmaB` | 1 | 0 | empty |

The two 2-person groups hold the same pair and hand off on the same day: the second was
made when the first stopped being used. Which of them becomes the ledger is a decision, so
`MigrationService.Target` names the groups that fold into one ledger, chosen with
`HALFHAZARD_MIGRATION_GROUPS` in `.migration-env`. With no target set, every group becomes
its own ledger — useful for looking around, wrong as a destination.

Targeting `WwQYJYtRPYpAVV6koJtO` alone comes back clean. Folding both 2-person groups
together needs `--force`, for one expense:

- `dvzikHaLxk18NRF461gz` "Ouid Drinks Fancy" — $112 with splits of 375/375, left over from
  when it was $750. The ratio is unambiguous so it migrates to $56/$56, and it is settled,
  so no balance moves either way.
- The two blocking issues in the scratch group are a `.currentUserOwes` with nobody else in
  the group and a splits map of all zeroes. Both net to $0.00.

Running the harness: `./scripts/migrate.sh dry-run | commit | audit`. Configuration goes in
`.migration-env` in the repo root (gitignored). `commit` writes; the other two only read.
`audit` reads the database back and checks it against what should be there, which is the
only way to tell a migration that worked from one that never ran.

Three things about running a migration from a test had to be worked out, none of them
obvious, all of them silent when they go wrong:

- **`xcodebuild test` does not pass its environment to the test process.** Exported
  variables never arrive, so the harness skipped itself — and a skipped test reports
  success. `TEST_RUNNER_`-prefixed variables do not work either for an app-hosted unit test.
  Configuration is therefore read from `.migration-env`, located relative to `#filePath`.
- **`print` from an app-hosted unit test does not reach xcodebuild's output**, and Xcode
  keeps assertion detail in the result bundle rather than the log. The report is an
  `XCTAttachment`; `migrate.sh` pulls it back out with `xcresulttool export attachments`.
- **The app is sandboxed**, so the test process can read the repo but cannot write to it.
  That rules out simply writing the report to a file.

The harness signs in with the credentials in `.migration-env` only when there is no session
already: the test host shares the app's keychain, so it usually runs as whoever is signed
into the app.

### Phase 3 output

`Services/LedgerService.swift` — a `LedgerDataSource` protocol and its Firestore
implementation, where `entries(in:)` is an `AsyncThrowingStream` over a snapshot listener.
`ViewModels/LedgerStore.swift` — `@MainActor @Observable`, holds the ledger, the entries,
both users, and every derived figure. 12 tests in
`halfhazardTests/ViewModels/LedgerStoreTests.swift`, run by `./run_tests.sh store`.

The store is the only place a balance is computed, and the only thing that talks to the
data source, so the `NotificationCenter` bus has nothing left to do. Tests run against an
in-memory `LedgerDataSource` that really stores entries and really pushes snapshots, so
"the other person added an expense and it appeared" is an assertion rather than a mock
expectation.

The migration ran against production on 2026-07-31: `ledgers/WwQYJYtRPYpAVV6koJtO` holds
80 entries (74 expenses + 6 settlements) folded from both 2-person groups, audited back
with balances matching. The old `expenses` collection is untouched.

### Phase 4 output

`Views/Ledger/` — `LedgerScreen` (balance header, day-grouped feed, toolbar), `BalanceHeader`,
`EntryRow`, `AddExpenseSheet`, `SettleSheet`, and `DemoLedger` (debug only).
`Models/BalancePhrasing.swift` holds every sentence the UI says, out of the views and tested
from both sides — reading backwards is the defect that started this, so "Laura paid" versus
"You paid" is an assertion, not a hope. 6 tests in `BalancePhrasingTests`, plus 3 UI tests in
`halfhazard_iosUITests/LedgerScreenUITests.swift` that drive the real app on a simulator.

Both roots now show `LedgerScreen`; the old implementations are renamed `legacyMainAppView`
and wait for phase 5. The add sheet asks who paid and how it splits as two separate
questions, which the old `SplitType` could not express — it meant both at once, which is why
its labels could never be right for both people.

`-demoLedger` as a launch argument runs the screen against fixtures with no sign-in, which
is how the UI tests drive it and how to look at the screen without touching the database.
Debug builds only. `./run_tests.sh ui` runs those tests; they are not in `all` because they
need a simulator and take about a minute.

Two things worth knowing for phase 5. SwiftUI's `Group` is shadowed by the app's own `Group`
model, so `LedgerScreen` says `SwiftUI.Group` — that can go back to normal once the model
does. And `halfhazard_iosUITests` uses classic file references rather than a synchronized
group, so a new file there has to be added to `project.pbxproj` by hand or it silently is
not compiled: `-only-testing` then matches nothing and the run reports success having run
zero tests.

### Phase 5 output

23 files gone, **8,272 lines deleted**, against ~1,100 added across phases 3–5. The app's own
source is now 5,542 lines. What went:

- The group world as planned: `GroupListView`, `CreateGroupForm`, `JoinGroupForm`,
  `ManageGroupSheet`, `GroupViewModel`.
- The expense UI the one screen replaces: `ExpenseListView`, `ExpenseRow`,
  `ExpenseDetailView`, `CreateExpenseForm`, `EditExpenseForm`, `CustomSplitView`,
  `ImportExpensePreview`, `CustomTabBar`, `ExpenseViewModel`.
- The template UI and `ExpenseTemplateViewModel`. The `ExpenseTemplate` model and its
  service stay, so phase 6 ports onto a clean slate rather than editing the old forms.
- Both roots, replaced by one `AppRoot.swift` of about 145 lines: splash, sign-in, ledger.
  With `ContentView.swift` went its two catalogued defects — the `.navigationDestination`
  attached to the `NavigationStack` rather than its content, and ~165 lines of `#if os(iOS)`
  that never compiled because the pbxproj excluded the file from that target.
- `AppNavigation`: a `NavigationPath` and a `Destination` enum for forms that no longer
  exist. One screen, two sheets, both local state.
- `ContentView.swift.bak` and `.orig`, two stale copies that had been committed.
- `GroupViewModelTests`, `ExpenseViewModelTests`, `ServiceBehaviorTests` — all three
  exercised deleted view models.

The pbxproj needed hand-editing twice: `iOSContentView.swift` was referenced classically by
the iOS target, and the synchronized-folder exception set still excluded `ContentView.swift`
from that target by name, which fails the build as a missing input once the file is gone.

`run_tests.sh` now fails a suite that runs *no* tests. Deleting `ServiceBehaviorTests` left
its entry in the script matching nothing, which reported a cheerful pass — the same shape as
the `-only-testing` path bug found in phase 2, and worth catching structurally rather than
one instance at a time.

Verified after the deletion: both targets build, every suite passes, the three UI tests still
drive the real app, and `./scripts/migrate.sh store` still reads the live ledger — 80 entries,
no error.

### Names, and why they live on the ledger

`users/{id}` is readable only by that user, so neither member can read the other's profile.
The first version of the store loaded both profiles on start and treated the denied read as
fatal — so the screen came up empty behind "Missing or insufficient permissions" on a ledger
whose 80 entries had loaded perfectly well. Two fixes, both worth keeping:

- Names are decoration. Failing to load them never costs the ledger; the store catches that
  read on its own. `LedgerStoreTests.testADeniedProfileReadDoesNotCostTheLedger` pins it.
- `Ledger.memberNames` carries display names, each written by the person it belongs to when
  their app starts. Both members can already read and write the ledger document, so this
  needs no loosening of the `users` rule.

The consequence: the other person shows as "Them" until they open the new app once and
publish their name. Either member *may* write the other's entry in `memberNames` — the rule
allows it — so a rename affordance is possible if waiting is not acceptable.

### The bootstrap crash, explained

The long-standing "test suites crash when run together" is a stale process, not the tests.
The test host is the app itself, so it opens Firestore's leveldb cache in the app's sandbox
container, and only one process can hold that lock. A host left over from an earlier run —
a crashed run always leaves one — makes the next one abort inside
`FirestoreClient::Initialize` before any test runs.

`run_tests.sh` and `scripts/migrate.sh` now clear strays before each run. They also stop
believing xcodebuild's exit code: it launches host processes it does not run tests in, and
those still abort on the lock, failing the whole invocation while every test passed. Both
scripts judge by the test results and say so when they override.

## Other defects to fix on the way through

- `ContentView.swift:304` — `.navigationDestination(for:)` is attached to the
  `NavigationStack` itself rather than its content, so it sits outside the navigation
  hierarchy. Real macOS navigation bug. The iOS version (`iOSContentView.swift:334`) is
  correct.
- `ContentView.swift:344-507` — ~165 lines of `#if os(iOS)` code that never compiles;
  the pbxproj excludes `ContentView.swift` from the iOS target.
- `ExpenseRow.swift:173` — a Firestore user fetch per row, just to show a name. Load both
  users once into the store instead.
- Nothing is live: every read is a one-shot `getDocuments()`, with a hand-rolled
  `NotificationCenter` bus (`RefreshExpensesNotification`, `ExpenseChangedNotification`)
  faking reactivity. Replace with snapshot listeners.
- `GroupViewModel.swift:465` — dev mode returns `Double.random(in: -100...100)` as a
  balance. Dev mode should be a service implementation behind a protocol, not an `if`
  in twenty methods.
- `ExpenseTemplate.swift:133-148` — `TemplateItem.createExpense` maps custom percentages
  to members **by array index**, so who gets which percentage is arbitrary. Still broken
  despite the "templates now correctly calculate split %age" commit.
- Both `ContentView.onAppear` and `GroupListView.task` call `loadGroups()`, after which
  `updateAllGroupBalances()` serially refetches every expense of every group.

## Known pre-existing test issues

- `ExpenseViewModelTests.testCreateExpenseWithCustomSplit` fails at `294a77f`. It covers
  the custom-split path being replaced; left alone deliberately.
- Running the whole test target in one pass aborts at bootstrap, though all 16 suites
  pass individually. That is why `run_tests.sh` invokes `xcodebuild` once per suite.
  Verify results per suite. Even per-suite, a run occasionally fails at bootstrap and
  passes on a retry.
- Fixed in phase 2: `run_tests.sh` passed `-only-testing:halfhazardTests/Services/MockServiceTests`.
  That flag takes `Target/Class`, not a file path, so it matched nothing and the `mocks` and
  `firebase` suites had been reporting success without running a single test. Both pass now
  that they actually execute (9 and 4 tests).
