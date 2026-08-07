//
//  ParentalGate.swift
//  Skelzies
//
//  App Review Guideline 1.3 requires that apps in the Kids Category place any
//  link out of the app behind a parental gate. This presents a two-digit
//  multiplication problem — a challenge Apple accepts as appropriate, since it
//  is beyond the arithmetic ability of the app's target age band.
//
//  Usage:
//
//      @StateObject private var gate = ParentalGateController()
//
//      Button("Privacy Policy") {
//          gate.challenge { openURL(privacyPolicyURL) }
//      }
//      .parentalGate(gate)
//
//  Only needed if Skelzies ships in the Kids Category. If the app is listed
//  under Games → Board instead, this file can be left out of the target.
//

import SwiftUI

// MARK: - Controller

@MainActor
final class ParentalGateController: ObservableObject {
    @Published var isPresented = false

    private var pendingAction: (() -> Void)?

    /// Present the gate. `action` runs only on a correct answer.
    func challenge(_ action: @escaping () -> Void) {
        pendingAction = action
        isPresented = true
    }

    func succeed() {
        let action = pendingAction
        pendingAction = nil
        isPresented = false
        // Let the sheet finish dismissing before opening an external app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            action?()
        }
    }

    func cancel() {
        pendingAction = nil
        isPresented = false
    }
}

// MARK: - View modifier

extension View {
    func parentalGate(_ controller: ParentalGateController) -> some View {
        sheet(isPresented: Binding(
            get: { controller.isPresented },
            set: { if !$0 { controller.cancel() } }
        )) {
            ParentalGateView(controller: controller)
        }
    }
}

// MARK: - Gate view

struct ParentalGateView: View {
    @ObservedObject var controller: ParentalGateController

    @State private var left = Int.random(in: 12...19)
    @State private var right = Int.random(in: 12...19)
    @State private var entry = ""
    @State private var wrongShake = false
    @State private var attempts = 0

    private var answer: Int { left * right }

    var body: some View {
        ZStack {
            Color(UIColor(rgb: 0x1D1E22)).ignoresSafeArea()

            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.yellow)
                    Text("Ask a Grown-Up")
                        .font(.custom("ChalkboardSE-Bold", size: 28))
                        .foregroundColor(.white)
                    Text("Solve this to continue")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .padding(.top, 30)

                // The challenge
                Text("\(left) × \(right) = ?")
                    .font(.custom("ChalkboardSE-Bold", size: 44))
                    .foregroundColor(.white)
                    .padding(.vertical, 4)

                // Entry display
                Text(entry.isEmpty ? " " : entry)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .frame(width: 180, height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(wrongShake ? Color.red : Color.white.opacity(0.25),
                                            lineWidth: wrongShake ? 2 : 1)
                            )
                    )
                    .offset(x: wrongShake ? 8 : 0)
                    .animation(.default.repeatCount(3, autoreverses: true).speed(6), value: wrongShake)

                // Keypad
                VStack(spacing: 10) {
                    ForEach(0..<3) { row in
                        HStack(spacing: 10) {
                            ForEach(1...3, id: \.self) { col in
                                keypadButton("\(row * 3 + col)")
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        keypadButton("⌫", isAction: true) {
                            if !entry.isEmpty { entry.removeLast() }
                        }
                        keypadButton("0")
                        keypadButton("✓", isAction: true, tint: .yellow) {
                            submit()
                        }
                    }
                }

                if attempts >= 2 {
                    Text("Grown-ups: this keeps kids from leaving the app by accident.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                Button("Cancel") { controller.cancel() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: 420)
        }
    }

    // MARK: Keypad

    private func keypadButton(_ label: String,
                              isAction: Bool = false,
                              tint: Color = .white,
                              action: (() -> Void)? = nil) -> some View {
        Button {
            if let action {
                action()
            } else if entry.count < 4 {
                entry += label
            }
        } label: {
            Text(label)
                .font(.custom("ChalkboardSE-Bold", size: 24))
                .foregroundColor(isAction ? tint : .white)
                .frame(width: 74, height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        guard let value = Int(entry) else { return }
        if value == answer {
            controller.succeed()
        } else {
            attempts += 1
            entry = ""
            wrongShake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                wrongShake = false
                // New problem each failure, so guessing doesn't converge.
                left = Int.random(in: 12...19)
                right = Int.random(in: 12...19)
            }
        }
    }
}

#Preview {
    ParentalGateView(controller: ParentalGateController())
}
