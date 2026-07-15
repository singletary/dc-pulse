import PhotosUI
import SwiftUI
import UIKit

struct Report311View: View {
    private enum FocusedField: Hashable {
        case details
        case address
    }

    @Environment(LocationService.self) private var locationService
    @Environment(\.openURL) private var openURL
    @State private var viewModel = Report311ViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingHandoffConfirmation = false
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        Form {
            Section {
                if let data = viewModel.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable().scaledToFit().frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Photo for the service request")
                } else {
                    ContentUnavailableView(
                        "Start with a photo",
                        systemImage: "camera.viewfinder",
                        description: Text("DC Pulse can suggest a request type while keeping image analysis on this device.")
                    )
                }

                HStack {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose Photo", systemImage: "photo")
                    }
                    Spacer()
                    Button { showingCamera = true } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                }
            } header: {
                Text("What needs attention?")
            } footer: {
                Text("Photo analysis stays on this device. DC Pulse does not read the photo’s location metadata or upload it during analysis.")
            }

            Section("Request details") {
                if viewModel.analysisState == .analyzing {
                    HStack { ProgressView(); Text("Looking for useful details…") }
                } else if viewModel.analysisState == .failed {
                    Label("The photo could not be analyzed. You can still complete the draft manually.", systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Picker("Request type", selection: $viewModel.draft.category) {
                    ForEach(Report311Draft.Category.allCases) { category in
                        Label(category.displayName, systemImage: category.systemImage).tag(category)
                    }
                }
                .pickerStyle(.navigationLink)

                TextField("Describe what you see", text: $viewModel.draft.details, axis: .vertical)
                    .lineLimit(3...7)
                    .focused($focusedField, equals: .details)
                    .submitLabel(.done)
                    .accessibilityIdentifier("report311.details")
            }

            Section {
                TextField("Address or nearest intersection", text: $viewModel.draft.address)
                    .textContentType(.fullStreetAddress)
                    .focused($focusedField, equals: .address)
                    .submitLabel(.done)

                if viewModel.draft.coordinate != nil {
                    Label("Using your current DC location", systemImage: "location.fill")
                        .foregroundStyle(.indigo)
                }

                Button {
                    locationService.requestCurrentLocation()
                    viewModel.useCurrentLocation(locationService.coordinate, address: locationService.locationLabel)
                } label: {
                    Label("Use My Current Location", systemImage: "location")
                }
            } header: {
                Text("Where is it?")
            } footer: {
                if viewModel.imageData != nil && viewModel.draft.coordinate == nil {
                    Text("Current location is unavailable. Enter a DC address or allow location access and try again.")
                }
            }

            Section {
                Text("Review every suggestion before submitting. DC Pulse copies your draft for the official DC311 app or website; it does not submit or post anything on your behalf.")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Button(action: prepareHandoff) {
                Label("Continue with DC 311", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
            .accessibilityIdentifier("report311.continue")
        }
        .navigationTitle("Report to 311")
        .navigationBarTitleDisplayMode(.inline)
        .onSubmit { focusedField = nil }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.setPhoto(data)
                    useCurrentLocationIfAvailable()
                }
            }
        }
        .onChange(of: locationService.updateSequence) { _, _ in
            viewModel.useCurrentLocation(locationService.coordinate, address: locationService.locationLabel)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView { data in
                Task {
                    await viewModel.setPhoto(data)
                    useCurrentLocationIfAvailable()
                }
            }
                .ignoresSafeArea()
        }
        .alert("Draft copied", isPresented: $showingHandoffConfirmation) {
            Button("Open DC311 App") { openURL(DC311Handoff.appStoreURL) }
            Button("Use Official Website") { openURL(DC311Handoff.websiteURL) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The official web portal is not loading reliably on some iPhones. For the best handoff, open the District's DC311 app, then paste the reviewed details and attach the photo.")
        }
    }

    private func useCurrentLocationIfAvailable() {
        if locationService.coordinate != nil {
            viewModel.useCurrentLocation(locationService.coordinate, address: locationService.locationLabel)
        } else {
            locationService.requestCurrentLocation()
        }
    }

    private func prepareHandoff() {
        focusedField = nil
        UIPasteboard.general.string = viewModel.draft.summaryForOfficialPortal
        showingHandoffConfirmation = true
    }
}
