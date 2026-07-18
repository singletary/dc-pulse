import MapKit
import SwiftUI
import SwiftData
import UIKit

struct ItemDetailsView: View {
    let item: PulseItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var watchedItems: [WatchedPulseItem]
    @State private var copyConfirmation: String?
    @State private var showing311Handoff = false

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
                                .textSelection(.enabled)
                        }
                    }
                }.padding(.vertical, 6)
            }
            Section {
                Button {
                    toggleWatch()
                } label: {
                    Label(watchActionTitle, systemImage: watchActionIcon)
                }
                Text(watchActionDescription)
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let coordinate = item.coordinate {
                Section("Location") {
                    Map(initialPosition: .region(MKCoordinateRegion(center: coordinate.clLocationCoordinate, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                        Marker(item.title, coordinate: coordinate.clLocationCoordinate)
                    }.frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                    if let address = item.address {
                        CopyableDetailRow(label: "Address", value: address) { copy(address, label: "Address") }
                    }
                    if let area = item.wardOrNeighborhood {
                        CopyableDetailRow(label: "Area", value: area) { copy(area, label: "Area") }
                    }
                }
            }
            Section("Details") {
                ForEach(detailFields) { field in
                    CopyableDetailRow(label: field.label, value: field.value) {
                        copy(field.value, label: field.label)
                    }
                }
                Button { copy(ItemDetailsContent.summary(for: detailFields), label: "Details") } label: {
                    Label("Copy All Details", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("item-details.copy-all")
            }
            Section("Source") {
                switch item.id.source {
                case .serviceRequests311:
                    Label("Public record supplied by DC 311 and DC Open Data", systemImage: "building.columns")
                    Button { prepare311Handoff() } label: {
                        Label("Check This Request in DC 311", systemImage: "magnifyingglass")
                    }
                    Text("Copies the request ID, then opens the official DC 311 service so you can paste it into the status search.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link("Submit a new request with DC 311", destination: DC311RequestHandoff.officialURL)
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
                    ForEach(violationFields) { field in
                        CopyableDetailRow(label: field.label, value: field.value) {
                            copy(field.value, label: field.label)
                        }
                    }
                    Button { copy(ItemDetailsContent.summary(for: violationFields), label: "Report details") } label: {
                        Label("Copy Report Details", systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("item-details.copy-report")
                }
            }
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Request ID copied", isPresented: $showing311Handoff) {
            Button("Open DC 311") { openURL(DC311RequestHandoff.officialURL) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(DC311RequestHandoff.instruction(for: item.id.sourceIdentifier))
        }
        .overlay(alignment: .bottom) {
            if let copyConfirmation {
                Label(copyConfirmation, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 6, y: 2)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("item-details.copy-confirmation")
            }
        }
    }

    private var detailFields: [ItemDetailField] { ItemDetailsContent.fields(for: item) }
    private var violationFields: [ItemDetailField] { ItemDetailsContent.violationFields(for: item) }

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

    private var isWatched: Bool { matchingWatch != nil && matchingWatch?.isArchived == false }

    private var watchActionTitle: String {
        if matchingWatch?.isArchived == true { return "Restore Watch" }
        return isWatched ? "Stop Watching" : "Watch This Item"
    }

    private var watchActionIcon: String {
        if matchingWatch?.isArchived == true { return "arrow.uturn.backward.circle" }
        return isWatched ? "bell.slash" : "bell.badge"
    }

    private var watchActionDescription: String {
        if matchingWatch?.isArchived == true {
            return "Restore this item to active watch checks in Places."
        }
        return isWatched
            ? "DC Pulse will track changes when fresh data is available."
            : "Watch this item to keep it available in Places and track status changes."
    }

    private func openXComposer() {
        guard let nativeURL = XPostComposer.nativeComposeURL(message: statusUpdateMessage),
              let webURL = XPostComposer.composeURL(message: statusUpdateMessage) else { return }
        UIApplication.shared.open(nativeURL) { opened in
            guard !opened else { return }
            UIApplication.shared.open(webURL)
        }
    }

    private func prepare311Handoff() {
        UIPasteboard.general.string = item.id.sourceIdentifier
        showing311Handoff = true
    }

    private func toggleWatch() {
        if let matchingWatch {
            if matchingWatch.isArchived {
                matchingWatch.restore()
            } else {
                modelContext.delete(matchingWatch)
            }
        } else {
            modelContext.insert(WatchedPulseItem(item: item))
        }
        try? modelContext.save()
    }

    private func copy(_ value: String, label: String) {
        UIPasteboard.general.string = value
        let confirmation = "\(label) copied"
        withAnimation { copyConfirmation = confirmation }
        Task {
            try? await Task.sleep(for: .seconds(2))
            guard copyConfirmation == confirmation else { return }
            withAnimation { copyConfirmation = nil }
        }
    }
}

private struct CopyableDetailRow: View {
    let label: String
    let value: String
    let copy: () -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(value)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy \(label)")
            }
        } label: {
            Text(label)
        }
    }
}
