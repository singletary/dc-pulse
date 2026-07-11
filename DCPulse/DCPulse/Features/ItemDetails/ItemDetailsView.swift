import MapKit
import SwiftUI

struct ItemDetailsView: View {
    let item: PulseItem

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.category).font(.subheadline).foregroundStyle(.secondary)
                    Text(item.title).font(.title2.bold())
                    StatusPill(status: item.status)
                    if let summary = item.summary { Text(summary).foregroundStyle(.secondary) }
                }.padding(.vertical, 6)
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
                LabeledContent("Opened") { Text(item.openedAt, format: .dateTime.month().day().year()) }
                if let updatedAt = item.updatedAt { LabeledContent("Updated") { Text(updatedAt, format: .dateTime.month().day().year()) } }
                if let closedAt = item.closedAt { LabeledContent("Completed") { Text(closedAt, format: .dateTime.month().day().year()) } }
                if let agency = item.responsibleAgency { LabeledContent("Agency", value: agency) }
                ForEach(item.sourceAttributes) { LabeledContent($0.label, value: $0.value) }
            }
            Section("Source") {
                if let url = item.sourceURL { Link("View original DC data", destination: url) }
                else { Text("Sample record — no live source link").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
