import SwiftUI

struct RestaurantHealthView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 44)).foregroundStyle(.red)
                    Text("Check before you dine")
                        .font(.title2.bold())
                    Text("Search official DC Health inspection reports for restaurants, markets, bakeries, caterers, and other food establishments.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                Link(destination: RestaurantInspectionPortal.searchURL) {
                    Label("Search Official Inspection Reports", systemImage: "magnifyingglass")
                }
                Link(destination: RestaurantInspectionPortal.closuresURL) {
                    Label("View Closures and Restorations", systemImage: "exclamationmark.octagon")
                        .foregroundStyle(.red)
                }
            }

            Section("How DC reports results") {
                healthRow(
                    title: "Priority",
                    detail: "Foodborne-illness risks that generally require correction within five days.",
                    color: .red
                )
                healthRow(
                    title: "Priority Foundation",
                    detail: "Practices or systems needed to control food-safety risks.",
                    color: .orange
                )
                healthRow(
                    title: "Core",
                    detail: "Sanitation, facilities, equipment, and general maintenance requirements.",
                    color: .yellow
                )
            }

            Section {
                Label("DC Health uses pass/fail inspections—not letter grades, percentages, or restaurant ratings.", systemImage: "checkmark.seal")
                Link("Understand Inspection Results", destination: RestaurantInspectionPortal.guidanceURL)
            } footer: {
                Text("DC Pulse links to the authoritative public reports. Nearby inspection alerts will be added only after a stable, supported data interface is verified.")
            }
        }
        .navigationTitle("Restaurant Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func healthRow(title: String, detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(color).frame(width: 12, height: 12).padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
