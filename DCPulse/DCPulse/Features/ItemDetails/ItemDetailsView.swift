import MapKit
import SwiftUI
import SwiftData
import UIKit

struct ItemDetailsView: View {
    let item: PulseItem
    @Environment(\.modelContext) private var modelContext
    @Query private var watchedItems: [WatchedPulseItem]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.category).font(.subheadline).foregroundStyle(.secondary)
                    Text(item.title).font(.title2.bold())
                    StatusPill(status: item.status)
                    if let summary = item.summary {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.id.source == .serviceRequests311 ? "Submitted details" : "Work description")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(summary)
                        }
                    }
                }.padding(.vertical, 6)
            }
            Section {
                Button {
                    toggleWatch()
                } label: {
                    Label(isWatched ? "Stop Watching" : "Watch This Item",
                          systemImage: isWatched ? "bell.slash" : "bell.badge")
                }
                Text(isWatched
                     ? "DC Pulse will track changes when fresh data is available."
                     : "Watch this item to keep it available in Places and track status changes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let coordinate = item.coordinate {
                Section("Location") {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate.clLocationCoordinate, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                        Marker(item.title, coordinate: coordinate.clLocationCoordinate)
                    }.frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                    if let address = item.address { Label(address, systemImage: "mappin.and.ellipse") }
                    if let area = item.wardOrNeighborhood { LabeledContent("Area", value: area) }
                }
            }
            Section("Details") {
                LabeledContent("Source", value: item.id.source.displayName)
                LabeledContent(identifierLabel, value: item.id.sourceIdentifier)
                LabeledContent(primaryDateLabel) { Text(item.openedAt, format: .dateTime.month().day().year()) }
                if let updatedAt = item.updatedAt { LabeledContent("Updated") { Text(updatedAt, format: .dateTime.month().day().year()) } }
                if let closedAt = item.closedAt { LabeledContent("Completed") { Text(closedAt, format: .dateTime.month().day().year()) } }
                if let agency = item.responsibleAgency { LabeledContent("Agency", value: agency) }
                ForEach(item.sourceAttributes) { LabeledContent($0.label, value: $0.value) }
            }
            Section("Source") {
                switch item.id.source {
                case .serviceRequests311:
                    Label("Public record supplied by DC 311 and DC Open Data", systemImage: "building.columns")
                    Text("Use the request ID above when checking with DC 311.").font(.caption).foregroundStyle(.secondary)
                    Link("Submit or check a request with DC 311", destination: URL(string: "https://311.dc.gov")!)
                    Button { openXComposer() } label: {
                        Label("Ask for a status update on X", systemImage: "bubble.left.and.bubble.right")
                    }
                    Text("Opens a pre-filled post for you to review. DC Pulse never posts on your behalf.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .buildingPermits2026:
                    Label("Public record supplied by the DC Department of Buildings and DC Open Data", systemImage: "building.columns")
                    if let sourceURL = item.sourceURL { Link("View the Building Permits dataset", destination: sourceURL) }
                case .ddotConstructionPermits2026:
                    Label("Public record supplied by DDOT and DC Open Data", systemImage: "building.columns")
                    if let sourceURL = item.sourceURL { Link("View the DDOT Construction Permits dataset", destination: sourceURL) }
                }
            }
            if let reportingDestination = ViolationReportingDestination(item: item) {
                Section("Report a possible violation") {
                    Link(destination: reportingDestination.url) {
                        Label(reportingDestination.actionTitle, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                    .tint(.red)
                    Text(reportingDestination.guidance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LabeledContent("Reference", value: item.id.sourceIdentifier)
                    if let address = item.address {
                        LabeledContent("Location", value: address)
                    }
                }
            }
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var identifierLabel: String {
        switch item.id.source {
        case .serviceRequests311: "Request ID"
        case .buildingPermits2026: "Permit ID"
        case .ddotConstructionPermits2026: "Tracking or permit ID"
        }
    }

    private var primaryDateLabel: String {
        switch item.id.source {
        case .serviceRequests311: "Opened"
        case .buildingPermits2026: "Issued"
        case .ddotConstructionPermits2026: "Applied"
        }
    }

    private var statusUpdateMessage: String {
        var parts = ["@311DCGov Could you provide an update on DC 311 request \(item.id.sourceIdentifier)?", item.title]
        if let address = item.address { parts.append(address) }
        parts.append("Current status: \(item.status.displayName)")
        return parts.joined(separator: " — ")
    }

    private var matchingWatch: WatchedPulseItem? {
        let key = WatchedPulseItem.stableKey(for: item.id)
        return watchedItems.first { $0.stableKey == key }
    }

    private var isWatched: Bool { matchingWatch != nil }

    private func openXComposer() {
        guard let nativeURL = XPostComposer.nativeComposeURL(message: statusUpdateMessage),
              let webURL = XPostComposer.composeURL(message: statusUpdateMessage) else { return }
        UIApplication.shared.open(nativeURL) { opened in
            guard !opened else { return }
            UIApplication.shared.open(webURL)
        }
    }

    private func toggleWatch() {
        if let matchingWatch {
            modelContext.delete(matchingWatch)
        } else {
            modelContext.insert(WatchedPulseItem(item: item))
        }
        try? modelContext.save()
    }
}
