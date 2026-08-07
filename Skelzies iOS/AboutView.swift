//
//  AboutView.swift
//  Skelzies
//
//  About screen: version, credits, links to privacy policy and support,
//  short how-to-play recap. Presented as a sheet from the SetupView.
//
//  KIDS CATEGORY NOTE (App Review Guideline 1.3):
//  All three external links below are wrapped in a parental gate. If Skelzies
//  ships outside the Kids Category (e.g. Games -> Board), set
//  `requiresParentalGate` to false and links open directly.
//

import SwiftUI

// MARK: - AboutView

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var gate = ParentalGateController()

    /// Set to false if the app is NOT listed in the Kids Category.
    private let requiresParentalGate = true

    // Update these before shipping.
    private let privacyPolicyURL = URL(string: "https://YOUR-USERNAME.github.io/skelzies-privacy/")!
    private let supportEmail     = "YOUR-EMAIL@example.com"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        ZStack {
            Color(UIColor(rgb: 0x1D1E22)).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // MARK: Header
                    VStack(spacing: 6) {
                        Text("SKELZIES")
                            .font(.custom("ChalkboardSE-Bold", size: 42))
                            .kerning(6)
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(-1.5))
                        Text("NYC EDITION")
                            .font(.caption)
                            .kerning(4)
                            .foregroundColor(.yellow.opacity(0.9))
                        Text("Version \(appVersion) · Build \(buildNumber)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .kerning(1.2)
                            .foregroundColor(.gray)
                            .padding(.top, 6)
                    }
                    .padding(.top, 12)

                    // MARK: How to play
                    section(title: "HOW TO PLAY") {
                        howToRow(number: "1", text: "Pick your cap. Lightweight flies far, Heavyweight barely flinches.")
                        howToRow(number: "2", text: "Touch the board and drag back to aim. The gauge breathes — release when you like the power.")
                        howToRow(number: "3", text: "Land squarely in boxes 1 through 13, in order. Clip the chalk and your turn's over.")
                        howToRow(number: "4", text: "In Traditional, first to 13 wins. In Knock Out, 13 crowns you Killer — hunt the other caps.")
                    }

                    // MARK: Info & links
                    section(title: "INFO") {
                        linkRow(icon: "hand.raised.fill",
                                label: "Privacy Policy",
                                subtext: "We collect nothing. Really.") {
                            openExternal(privacyPolicyURL)
                        }
                        linkRow(icon: "envelope.fill",
                                label: "Support",
                                subtext: supportEmail) {
                            if let url = URL(string: "mailto:\(supportEmail)?subject=Skelzies%20v\(appVersion)%20support") {
                                openExternal(url)
                            }
                        }
                        linkRow(icon: "star.fill",
                                label: "Rate on the App Store",
                                subtext: "One tap. Makes our whole week.") {
                            // Replace APP_ID after your app is live in App Store Connect.
                            if let url = URL(string: "itms-apps://itunes.apple.com/app/idAPP_ID?action=write-review") {
                                openExternal(url)
                            }
                        }
                    }

                    // MARK: Credits
                    section(title: "CREDITS") {
                        creditRow(role: "Design & Code", name: "[YOUR NAME]")
                        creditRow(role: "Playtesting",   name: "The block")
                        creditRow(role: "Inspired by",   name: "NYC · Skully · Loadies · Tops")
                    }

                    // MARK: Dedication
                    VStack(spacing: 10) {
                        chalkDivider
                        Text("For everyone who ever chalked a box on the block.")
                            .font(.custom("ChalkboardSE-Bold", size: 16))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        chalkDivider
                    }
                    .padding(.top, 4)

                    // MARK: Legal
                    Text("© \(currentYear()) [YOUR NAME OR STUDIO]. All rights reserved.")
                        .font(.system(size: 11, design: .monospaced))
                        .kerning(1)
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }

            // MARK: Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1.5))
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .parentalGate(gate)
    }

    // MARK: - External link handling

    /// Guideline 1.3: in the Kids Category, every link out of the app must sit
    /// behind a parental gate.
    private func openExternal(_ url: URL) {
        if requiresParentalGate {
            gate.challenge { openURL(url) }
        } else {
            openURL(url)
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .kerning(2.6)
                .foregroundColor(.gray)
                .padding(.leading, 4)
            VStack(spacing: 8) {
                content()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func howToRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.custom("ChalkboardSE-Bold", size: 20))
                .foregroundColor(.yellow)
                .frame(width: 26, alignment: .center)
            Text(text)
                .font(.system(size: 14.5))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func linkRow(icon: String, label: String, subtext: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.custom("ChalkboardSE-Bold", size: 16))
                        .foregroundColor(.white)
                    Text(subtext)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()
                if requiresParentalGate {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func creditRow(role: String, name: String) -> some View {
        HStack {
            Text(role)
                .font(.system(size: 12, weight: .semibold))
                .kerning(1.4)
                .foregroundColor(.gray)
            Spacer()
            Text(name)
                .font(.custom("ChalkboardSE-Bold", size: 15))
                .foregroundColor(.white)
        }
        .padding(.vertical, 3)
    }

    private var chalkDivider: some View {
        HStack(spacing: 6) {
            ForEach(0..<28) { _ in
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 3, height: 3)
            }
        }
    }

    private func currentYear() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: Date())
    }
}

// MARK: - Setup screen entry point
//
// Add a small button anywhere in SetupView to present this sheet, for example
// under the "Chalk it up" button or in a corner:
//
//   @State private var showAbout = false
//
//   Button("About") { showAbout = true }
//       .font(.system(size: 13, weight: .medium))
//       .foregroundColor(.gray)
//       .padding(.top, 4)
//
//   // …then, at the top of the SetupView's body ZStack:
//   .sheet(isPresented: $showAbout) { AboutView() }
//

#Preview {
    AboutView()
}
