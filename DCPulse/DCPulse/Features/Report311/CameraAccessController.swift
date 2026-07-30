import AVFoundation
import Observation
import UIKit

enum CameraAccessStatus: Equatable {
    case unavailable
    case notDetermined
    case authorized
    case denied
    case restricted
}

@MainActor
protocol CameraAccessProviding {
    var status: CameraAccessStatus { get }
    func requestAccess() async -> Bool
}

struct SystemCameraAccessProvider: CameraAccessProviding {
    var status: CameraAccessStatus {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return .unavailable
        }
        return switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

@MainActor @Observable
final class CameraAccessController {
    private(set) var status: CameraAccessStatus
    private let provider: any CameraAccessProviding

    init() {
        let provider = SystemCameraAccessProvider()
        self.provider = provider
        status = provider.status
    }

    init(provider: any CameraAccessProviding) {
        self.provider = provider
        status = provider.status
    }

    var guidance: String? {
        switch status {
        case .unavailable:
            "Camera is unavailable on this device. Choose an existing photo instead."
        case .denied:
            "Camera access is off. Allow access in Settings or choose an existing photo."
        case .restricted:
            "Camera access is restricted on this device. Choose an existing photo instead."
        case .notDetermined, .authorized:
            nil
        }
    }

    var canOpenSettings: Bool {
        status == .denied
    }

    func requestCamera() async -> Bool {
        status = provider.status
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await provider.requestAccess()
            status = granted ? .authorized : .denied
            return granted
        case .unavailable, .denied, .restricted:
            return false
        }
    }
}
