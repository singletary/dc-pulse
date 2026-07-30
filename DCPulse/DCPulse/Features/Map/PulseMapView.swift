import MapKit
import SwiftUI

struct PulseMapView: View {
    @State private var viewModel = PulseMapViewModel()
    @State private var selectedGroup: RequestMapGroup?
    @State private var statusFilter: PulseItem.Status?
    @State private var requestTypeFilter: String?
    @State private var selectedSources: Set<PulseItem.Source> = []
    @State private var candidateSearchCoordinate: PulseItem.Coordinate?
    @State private var categoryItems: [PulseItem]?
    @State private var isCategoryLoading = false
    @State private var showingFilters = false
    @State private var showingCoverageDetails = false
    @State private var expandedFilterSections: Set<MapFilterSection> = []
    @Environment(PulseDataStore.self) private var store
    @Environment(LocationService.self) private var locationService
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        ClusteredPulseMap(
            items: mapPipeline.annotationItems,
            searchCoordinate: store.searchCoordinate,
            radiusMeters: store.radius.rawValue * 1_609.344,
            renderingContext: mapRenderingContext,
            targetRegion: viewModel.region,
            centerRequestID: viewModel.centerRequestID,
            diagnostics: store.mapPerformanceDiagnostics,
            onRegionChange: updateCandidateSearchCoordinate,
            onSelection: { selectedGroup = $0 }
        )
        .accessibilityIdentifier("map.clustered")
        .accessibilityLabel("Requests map")
        .accessibilityValue(store.placeName)
        .ignoresSafeArea(edges: .vertical)
        .safeAreaInset(edge: .top) {
            Button {
                showingFilters = true
            } label: {
                Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.subheadline.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule()).padding(.top, 8)
            }
            .accessibilityIdentifier("map.filter")
            .accessibilityHint("Opens expandable filters for data, status, time, radius, and category")
            .overlay(alignment: .top) {
                if isMapUpdating {
                    VStack(spacing: 4) {
                        if store.isMapCoverageLoading, store.mapCoverageTotalUnits > 0 {
                            ProgressView(
                                value: Double(store.mapCoverageCompletedUnits),
                                total: Double(store.mapCoverageTotalUnits)
                            )
                            .progressViewStyle(.linear)
                            .accessibilityValue(
                                "\(store.mapCoverageCompletedUnits) of \(store.mapCoverageTotalUnits) " +
                                "\(store.mapCoverageTotalUnits == 1 ? "area" : "areas") complete"
                            )
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(mapLoadingLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if store.isShowingCachedResults, let lastUpdated = store.lastUpdated {
                            cachedResultsLabel(lastUpdated)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .frame(maxWidth: 340)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .offset(y: 54)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(mapLoadingLabel)
                } else if let warning = store.mapCoverageWarning {
                    Button {
                        showingCoverageDetails = true
                    } label: {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: 340, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .offset(y: 54)
                    .accessibilityIdentifier("map.coverageWarning")
                    .accessibilityHint("Shows affected areas and retry options")
                } else if store.isShowingCachedResults, let lastUpdated = store.lastUpdated {
                    cachedResultsLabel(lastUpdated)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: 340, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .offset(y: 54)
                        .accessibilityIdentifier("map.cachedResults")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    legend("New", .blue)
                    legend("Active", .orange)
                    legend("Resolved", .green)
                    legend("Multiple", .purple)
                    legend("Unknown", .gray)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .font(.caption.weight(.medium))
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFilters) { filterSheet }
        .sheet(isPresented: $showingCoverageDetails) { coverageDetails }
        .sheet(item: $selectedGroup) { group in
            NavigationStack {
                Group {
                    if group.items.count == 1 {
                        ItemDetailsView(item: group.items[0])
                    } else {
                        List(group.items) { item in
                            NavigationLink(value: item) { PulseItemRow(item: item) }
                        }
                        .navigationTitle("\(group.items.count) Items Here")
                        .navigationDestination(for: PulseItem.self) { ItemDetailsView(item: $0) }
                    }
                }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selectedGroup = nil }
                        }
                    }
            }
        }
        .onChange(of: store.searchCoordinate) { _, coordinate in
            candidateSearchCoordinate = nil
            viewModel.center(on: coordinate, radius: store.radius)
        }
        .onChange(of: store.radius) { _, radius in
            candidateSearchCoordinate = nil
            viewModel.center(on: store.searchCoordinate, radius: radius)
        }
        .task(id: mapCoverageContext) {
            viewModel.center(on: store.searchCoordinate, radius: store.radius)
            await prepareMapResults(for: mapCoverageContext)
        }
        .task(id: categoryLoadContext) { await loadSelectedCategory() }
        .onAppear { applyRequestedCategory() }
        .onChange(of: navigation.requestedMapCategory) { _, _ in applyRequestedCategory() }
        .overlay(alignment: .bottomTrailing) {
            Button {
                if let coordinate = locationService.coordinate {
                    candidateSearchCoordinate = nil
                    viewModel.center(on: coordinate, radius: store.radius)
                }
                locationService.requestCurrentLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.title3).padding(12)
                    .background(.regularMaterial, in: Circle())
                    .shadow(radius: 3, y: 1)
            }
            .accessibilityLabel("Return to current location")
            .accessibilityIdentifier("map.currentLocation")
            .accessibilityHint("Centers the map on you and reloads nearby requests")
            .disabled(locationService.state == .locating || locationService.state == .requestingPermission)
            .padding(.trailing, 14).padding(.bottom, 58)
        }
        .overlay(alignment: .bottom) {
            if let candidateSearchCoordinate {
                Button {
                    search(at: candidateSearchCoordinate)
                } label: {
                    Label("Search This Area", systemImage: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(radius: 3, y: 1)
                }
                .accessibilityHint("Reloads requests around the center of the visible map")
                .padding(.bottom, 58)
            }
        }
    }

    private var mapPipeline: MapItemPipeline {
        MapItemPipeline(
            items: categoryItems ?? store.items,
            selectedSources: selectedSources,
            status: statusFilter,
            category: requestTypeFilter
        )
    }

    private func updateCandidateSearchCoordinate(_ mapCenter: CLLocationCoordinate2D) {
        guard let coordinate = PulseItem.Coordinate(
            latitude: mapCenter.latitude,
            longitude: mapCenter.longitude
        ), coordinate.isWithinDCServiceArea else {
            candidateSearchCoordinate = nil
            return
        }
        let current = CLLocation(
            latitude: store.searchCoordinate.latitude,
            longitude: store.searchCoordinate.longitude
        )
        let proposed = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        candidateSearchCoordinate = current.distance(from: proposed) >= 100 ? coordinate : nil
    }

    private func search(at coordinate: PulseItem.Coordinate) {
        candidateSearchCoordinate = nil
        viewModel.center(on: coordinate, radius: store.radius)
        Task {
            await store.load(coordinate: coordinate, placeName: "Map Center", force: true)
        }
    }

    private var requestTypes: [String] {
        var categories = Set(store.items.lazy
            .filter { selectedSources.isEmpty || selectedSources.contains($0.id.source) }
            .map(\.category))
        if selectedSources.isEmpty || selectedSources.contains(.serviceRequests311) {
            categories.formUnion(store.requestCategories)
        }
        return categories.sorted()
    }
    private var availableSources: [PulseItem.Source] {
        Array(Set(store.items.map(\.id.source))).sorted { $0.displayName < $1.displayName }
    }

    private func applyRequestedCategory() {
        guard let category = navigation.requestedMapCategory else { return }
        statusFilter = navigation.requestedMapStatus
        selectCategory(category)
        navigation.requestedMapCategory = nil
        navigation.requestedMapStatus = nil
    }

    private func selectCategory(_ category: String?) {
        requestTypeFilter = category
        if category == nil {
            categoryItems = nil
            isCategoryLoading = false
        }
    }

    private func selectAllSources() {
        selectedSources = []
        validateCategoryFilter()
    }

    private func toggleSource(_ source: PulseItem.Source) {
        if selectedSources.isEmpty {
            selectedSources = Set(availableSources)
        }
        if selectedSources.contains(source) {
            guard selectedSources.count > 1 else { return }
            selectedSources.remove(source)
        } else {
            selectedSources.insert(source)
        }
        if selectedSources == Set(availableSources) { selectedSources = [] }
        validateCategoryFilter()
    }

    private func validateCategoryFilter() {
        if let requestTypeFilter, !requestTypes.contains(requestTypeFilter) {
            selectCategory(nil)
        }
    }

    private var isMapUpdating: Bool {
        store.isLoading || store.isMapCoverageLoading || isCategoryLoading
    }

    private func cachedResultsLabel(_ lastUpdated: Date) -> some View {
        Label {
            Text(
                store.cachedResultsAreStale
                    ? "Showing older cached markers · Updated \(lastUpdated, style: .relative)"
                    : "Showing cached markers · Updated \(lastUpdated, style: .relative)"
            )
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: store.cachedResultsAreStale ? "clock.badge.exclamationmark" : "clock")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private var mapLoadingLabel: String {
        if isCategoryLoading { return "Loading \(requestTypeFilter ?? "category") requests…" }
        if store.isLoading { return "Updating map…" }
        if store.isMapCoverageLoading {
            return store.mapCoverageLoadingDescription ?? "Loading nearby map results…"
        }
        return "Updating map…"
    }

    private var coverageDetails: some View {
        NavigationStack {
            List {
                Section {
                    Text("Markers already on the map remain usable. The sections below identify nearby results that did not finish updating.")
                }

                ForEach(store.mapCoverageIssues) { issue in
                    Section(issue.pass.label(selectedRadius: store.radius)) {
                        Label(issue.message, systemImage: "exclamationmark.triangle")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    Button {
                        showingCoverageDetails = false
                        Task { await store.retryMapCoverage() }
                    } label: {
                        Label("Retry Missing Results", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isMapCoverageLoading)
                    .accessibilityIdentifier("map.coverageRetry")
                }
            }
            .navigationTitle("Map Update Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingCoverageDetails = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var categoryLoadContext: MapCategoryLoadContext? {
        guard let requestTypeFilter else { return nil }
        return MapCategoryLoadContext(
            category: requestTypeFilter,
            isKnown311Category: store.requestCategories.contains(requestTypeFilter),
            coordinate: store.searchCoordinate,
            radius: store.radius,
            period: store.period
        )
    }

    private var mapCoverageContext: MapCoverageContext {
        MapCoverageContext(
            coordinate: store.searchCoordinate,
            radius: store.radius,
            period: store.period
        )
    }

    private var mapRenderingContext: MapRenderingContext {
        MapRenderingContext(
            searchCoordinate: store.searchCoordinate,
            radiusMiles: store.radius.rawValue,
            queryDays: store.period.queryDays
        )
    }

    private func prepareMapResults(for context: MapCoverageContext) async {
        do {
            while store.isLoading {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(50))
            }
            guard mapCoverageContext == context, store.state == .loaded else { return }

            // Let MapKit present the first result page before progressively adding
            // the larger summary set. This keeps the tab responsive on first open.
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()
            guard mapCoverageContext == context, store.state == .loaded else { return }
            await store.prepareMapResults()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private func loadSelectedCategory() async {
        guard let context = categoryLoadContext, context.isKnown311Category else {
            categoryItems = nil
            isCategoryLoading = false
            return
        }
        categoryItems = nil
        isCategoryLoading = true
        defer {
            if categoryLoadContext == context { isCategoryLoading = false }
        }
        do {
            let items = try await store.requestItems(in: context.category)
            try Task.checkCancellation()
            guard categoryLoadContext == context else { return }
            categoryItems = items
        } catch is CancellationError {
            return
        } catch {
            categoryItems = nil
        }
    }

    private var filterLabel: String {
        var parts: [String] = []
        if selectedSources.count == 1 {
            parts.append(selectedSources.first?.displayName ?? "Data")
        } else if selectedSources.count > 1 {
            parts.append("\(selectedSources.count) sources")
        }
        if let statusFilter { parts.append(statusFilter.displayName) }
        if let requestTypeFilter { parts.append(requestTypeFilter) }
        parts.append(store.radius.compactLabel)
        parts.append(store.period.label)
        return parts.joined(separator: " · ")
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        Label { Text(label) } icon: { Circle().fill(color).frame(width: 9, height: 9) }
    }

    private var filterSheet: some View {
        NavigationStack {
            List {
                filterDisclosure(.data, title: "Data", systemImage: "square.stack.3d.up") {
                    filterChoice("All data", isSelected: selectedSources.isEmpty) { selectAllSources() }
                    ForEach(availableSources, id: \.self) { source in
                        filterChoice(
                            source.displayName,
                            isSelected: selectedSources.isEmpty || selectedSources.contains(source)
                        ) { toggleSource(source) }
                    }
                }
                filterDisclosure(.status, title: "Status", systemImage: "circle.lefthalf.filled") {
                    filterChoice("All statuses", isSelected: statusFilter == nil) { statusFilter = nil }
                    ForEach(PulseItem.Status.allCases, id: \.self) { status in
                        filterChoice(status.displayName, isSelected: statusFilter == status) {
                            statusFilter = status
                        }
                    }
                }
                filterDisclosure(.time, title: "Time range", systemImage: "calendar") {
                    ForEach(PulseDataStore.Period.allCases) { period in
                        filterChoice(period.label, isSelected: store.period == period) {
                            Task {
                                await store.selectPeriod(period)
                            }
                        }
                    }
                }
                filterDisclosure(.radius, title: "Search radius", systemImage: "scope") {
                    ForEach(PulseDataStore.Radius.allCases) { radius in
                        filterChoice(radius.distanceLabel, isSelected: store.radius == radius) {
                            Task {
                                await store.selectRadius(radius)
                            }
                        }
                        .accessibilityIdentifier("map.radius.\(radius.rawValue)")
                        .accessibilityLabel(radius.accessibilityLabel)
                    }
                }
                filterDisclosure(.category, title: "Category", systemImage: "tag") {
                    filterChoice("All categories", isSelected: requestTypeFilter == nil) {
                        selectCategory(nil)
                    }
                    ForEach(requestTypes, id: \.self) { requestType in
                        filterChoice(requestType, isSelected: requestTypeFilter == requestType) {
                            selectCategory(requestType)
                        }
                    }
                }
            }
            .navigationTitle("Map Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { resetFilters() }
                        .disabled(filtersAreDefault)
                        .accessibilityIdentifier("map.filters.reset")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingFilters = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func filterDisclosure<Content: View>(
        _ section: MapFilterSection,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: expansionBinding(for: section)) {
            content()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .accessibilityIdentifier("map.filter.\(section.accessibilityName)")
        }
    }

    private func filterChoice(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                if isSelected { Image(systemName: "checkmark").foregroundStyle(.indigo) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func expansionBinding(for section: MapFilterSection) -> Binding<Bool> {
        Binding(
            get: { expandedFilterSections.contains(section) },
            set: { isExpanded in
                if isExpanded { expandedFilterSections.insert(section) }
                else { expandedFilterSections.remove(section) }
            }
        )
    }

    private var filtersAreDefault: Bool {
        selectedSources.isEmpty && statusFilter == nil && requestTypeFilter == nil &&
        store.radius == .halfMile && store.period == .thirtyDays
    }

    private func resetFilters() {
        selectedSources = []
        statusFilter = nil
        selectCategory(nil)
        Task {
            await store.resetSearchOptions()
        }
    }

}

private struct MapCoverageContext: Hashable {
    let coordinate: PulseItem.Coordinate
    let radius: PulseDataStore.Radius
    let period: PulseDataStore.Period
}

private struct MapCategoryLoadContext: Hashable {
    let category: String
    let isKnown311Category: Bool
    let coordinate: PulseItem.Coordinate
    let radius: PulseDataStore.Radius
    let period: PulseDataStore.Period
}

private enum MapFilterSection: Hashable {
    case data, status, time, radius, category

    var accessibilityName: String {
        switch self {
        case .data: "data"
        case .status: "status"
        case .time: "time"
        case .radius: "radius"
        case .category: "category"
        }
    }
}
