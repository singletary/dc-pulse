import Foundation

struct ViolationReportingDestination: Equatable {
    let actionTitle: String
    let url: URL
    let guidance: String

    init?(item: PulseItem) {
        switch item.id.source {
        case .serviceRequests311:
            return nil
        case .buildingPermits2026:
            guard let url = URL(string: "https://inspections.dob.dc.gov/forms/illegal_construction_inspection/step_1") else {
                return nil
            }
            actionTitle = "Report a building violation"
            self.url = url
            guidance = "Opens the official DOB inspection request. Include the permit reference and location shown below when describing the possible violation."
        case .ddotConstructionPermits2026:
            guard let url = URL(string: "https://311.dc.gov") else { return nil }
            actionTitle = "Report a public-space violation"
            self.url = url
            guidance = "DDOT directs possible public-space violations to DC 311. Include the permit reference and location shown below in your report."
        }
    }
}
