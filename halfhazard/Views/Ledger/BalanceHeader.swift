//
//  BalanceHeader.swift
//  halfhazard
//

import SwiftUI

/// The one number the app exists to show.
struct BalanceHeader: View {
    let standing: Balance.Standing
    let partnerName: String
    let onSettle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(standing.isSettled ? "You're square" : standing.magnitude.formatted())
                .font(standing.isSettled ? .title2.weight(.medium) : .system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(standing.isSettled ? .secondary : tint)

            if !standing.isSettled {
                Text(standing.sentence(partnerName: partnerName))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Settle up", action: onSettle)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .animation(.default, value: standing.amount)
    }

    private var tint: Color {
        standing.viewerIsOwed ? .green : .red
    }
}

#Preview("Owed") {
    BalanceHeader(
        standing: Balance.Standing(amount: Money(cents: 3210), partner: "laura"),
        partnerName: "Laura",
        onSettle: {}
    )
}

#Preview("Settled") {
    BalanceHeader(
        standing: Balance.Standing(amount: .zero, partner: "laura"),
        partnerName: "Laura",
        onSettle: {}
    )
}
