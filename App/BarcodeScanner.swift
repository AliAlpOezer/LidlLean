import AVFoundation
import SwiftUI

struct BarcodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    func makeUIViewController(context: Context) -> ScannerController { let controller = ScannerController(); controller.onCode = onCode; return controller }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}
final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession(); private var found = false
    override func viewDidLoad() { super.viewDidLoad(); guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }; session.addInput(input); let output = AVCaptureMetadataOutput(); guard session.canAddOutput(output) else { return }; session.addOutput(output); output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.ean8, .ean13, .upce]; let layer = AVCaptureVideoPreviewLayer(session: session); layer.videoGravity = .resizeAspectFill; layer.frame = view.bounds; view.layer.addSublayer(layer); DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); session.stopRunning() }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) { guard !found, let value = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }; found = true; session.stopRunning(); onCode?(value) }
}
