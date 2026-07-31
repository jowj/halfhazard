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

Reads `expenses`, writes a **new `entries` collection**. Never modifies existing data;
the old collection stays as a backup. Dry-run computes balances both ways and reports
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
2. Migration + dry-run verification harness ← next
3. `LedgerStore` on a Firestore snapshot listener, replacing the `NotificationCenter` bus
4. Single-screen UI: balance header, feed, add/settle sheets
5. Delete the group world, collapse the two root views
6. Port templates onto `SplitRule`
7. Firestore rules + indexes for `entries`

### Phase 1 output

`Models/Money.swift`, `SplitRule.swift`, `LedgerEntry.swift`, `Balance.swift`,
`Ledger.swift`; 36 tests in `halfhazardTests/Models/LedgerTests.swift`. All passing,
build green, nothing deleted.

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
  Verify results per suite.
