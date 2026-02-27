// Copyright (c) 2026 Gridmark Technologies Ltd (Signstr)
// https://github.com/signstr/Signstr-iOS
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
//  QRScannerView.swift
//  Signstr — AVFoundation QR code scanner for nsec import

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onScan: (String) -> Void

    @State private var cameraPermissionDenied = false

    var body: some View {
        ZStack {
            Color.sgBg.ignoresSafeArea()

            if cameraPermissionDenied {
                permissionDeniedContent
            } else {
                QRCameraPreview(onCodeFound: { code in
                    onScan(code)
                })
                .ignoresSafeArea()

                // Scan frame overlay
                VStack {
                    Spacer()

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.sgBorderHover, lineWidth: 2)
                        .frame(width: 240, height: 240)

                    Spacer().frame(height: 32)

                    Text("Point at an nsec QR code")
                        .font(.outfit(.light, size: 14))
                        .foregroundColor(.sgTextMuted)

                    Spacer()
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.sgTextBright)
                            .frame(width: 36, height: 36)
                            .background(Color.sgBgRaised.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 16)
                }
                Spacer()
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }

    private var permissionDeniedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(.sgTextGhost)

            Text("Camera access required")
                .font(.outfit(.light, size: 18))
                .foregroundColor(.sgTextBright)

            Text("Enable camera access in Settings to scan QR codes.")
                .font(.outfit(.light, size: 13))
                .foregroundColor(.sgTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("OPEN SETTINGS")
                    .font(.outfit(.regular, size: 11))
                    .tracking(4)
                    .foregroundColor(.sgTextBright)
                    .frame(width: 200, height: 44)
                    .background(Color.sgBorder)
                    .cornerRadius(Dimensions.buttonCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Dimensions.buttonCornerRadius)
                            .stroke(Color.sgBorderHover, lineWidth: 1)
                    )
            }
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            cameraPermissionDenied = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionDenied = !granted
                }
            }
        default:
            break
        }
    }
}

// MARK: - AVFoundation camera preview

struct QRCameraPreview: UIViewControllerRepresentable {
    var onCodeFound: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onCodeFound = onCodeFound
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeFound: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var hasFoundCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasFoundCode = false
        if let session = captureSession, !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = captureSession, session.isRunning {
            session.stopRunning()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasFoundCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else {
            return
        }

        hasFoundCode = true

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        captureSession?.stopRunning()
        onCodeFound?(value)
    }
}
