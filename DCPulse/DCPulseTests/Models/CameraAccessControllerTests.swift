import Testing
@testable import DCPulse

@MainActor
struct CameraAccessControllerTests {
    @Test func unavailableCameraExplainsThePhotoLibraryFallback() async {
        let provider = StubCameraAccessProvider(status: .unavailable)
        let controller = CameraAccessController(provider: provider)

        #expect(await controller.requestCamera() == false)
        #expect(controller.guidance == "Camera is unavailable on this device. Choose an existing photo instead.")
        #expect(controller.canOpenSettings == false)
        #expect(provider.requestCount == 0)
    }

    @Test(arguments: [CameraAccessStatus.denied, .restricted])
    func blockedCameraDoesNotRepeatTheSystemPrompt(status: CameraAccessStatus) async {
        let provider = StubCameraAccessProvider(status: status)
        let controller = CameraAccessController(provider: provider)

        #expect(await controller.requestCamera() == false)
        #expect(provider.requestCount == 0)
        #expect(controller.canOpenSettings == (status == .denied))
    }

    @Test(arguments: [true, false])
    func firstCameraRequestPublishesTheResult(granted: Bool) async {
        let provider = StubCameraAccessProvider(status: .notDetermined, requestResult: granted)
        let controller = CameraAccessController(provider: provider)

        #expect(await controller.requestCamera() == granted)
        #expect(provider.requestCount == 1)
        #expect(controller.status == (granted ? .authorized : .denied))
    }
}

@MainActor
private final class StubCameraAccessProvider: CameraAccessProviding {
    var status: CameraAccessStatus
    var requestCount = 0
    private let requestResult: Bool

    init(status: CameraAccessStatus, requestResult: Bool = false) {
        self.status = status
        self.requestResult = requestResult
    }

    func requestAccess() async -> Bool {
        requestCount += 1
        return requestResult
    }
}
