import SwiftUI

struct AboutView: View {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.red, .indigo)
                        .accessibilityHidden(true)
                    Text("DC Pulse")
                        .font(.title2.bold())
                    Text(versionDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }

            Section("Connect") {
                destinationLink("DC Pulse website", systemImage: "safari", destination: .website)
                destinationLink("Support", systemImage: "questionmark.circle", destination: .support)
                destinationLink("Privacy policy", systemImage: "hand.raised", destination: .privacy)
                destinationLink("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right", destination: .sourceCode)
            }

            Section("Public data") {
                Text(AboutContent.dataAttribution)
                destinationLink("Data sources and methodology", systemImage: "building.columns", destination: .dataInformation)
            }

            Section("Independent service") {
                Text(AboutContent.independentDisclaimer)
                Text("For emergencies, call 911. Use official District services to submit or confirm government requests.")
                    .font(.callout.weight(.semibold))
            }

            Section("Open source") {
                Text("The DC Pulse application source is available under the MIT License. DC public datasets retain their publishers’ own terms and attribution.")
                DisclosureGroup("MIT License") {
                    Text(AboutContent.license)
                        .font(.footnote)
                        .textSelection(.enabled)
                        .padding(.vertical, 8)
                }
                Text("DC Pulse currently has no third-party package dependencies.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About DC Pulse")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("about.view")
    }

    private var versionDescription: String {
        AboutContent.versionDescription(
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    private func destinationLink(
        _ title: String,
        systemImage: String,
        destination: AboutDestination
    ) -> some View {
        Link(destination: destination.url) {
            Label(title, systemImage: systemImage)
        }
        .accessibilityIdentifier("about.\(destination.accessibilityKey)")
        .accessibilityHint("Opens a secure webpage")
    }
}

#Preview {
    NavigationStack { AboutView() }
}
