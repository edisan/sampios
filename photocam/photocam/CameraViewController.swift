//
// NOTE: The code derived here was pulled from Apple's AVCamBuildingACameraApp sample
//       Only minor updates were made to extract only photo capture and simplication
//       of UI.  Doing so allowed understanding of the code involved to make use of camera
//       capture of photos, and storage to Photo Library.
//
//  CameraViewController.swift
//
//  Created by Eddie Sananikone on 5/2/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class CameraViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    
    // Orientation of the CameraView, may not be needed as we will work only with portrait for now
    var windowOrientation: UIInterfaceOrientation {
        return view.window?.windowScene?.interfaceOrientation ?? .portrait
    }
    
    /**
     * MARK: View Controller LCM Overrides
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable until session starts
        photoButton.isEnabled = false
        resumeButton.isHidden = true
        
        cameraView.session = session
        
        // get auth to access video and audio
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // already granted before
            break
        case .notDetermined:
            // user has not been presented with option to grant video access
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: {
                granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                
                self.sessionQueue.resume()
            })
        default:
            // user denied access previously
            setupResult = .notAuthorized
        }
        
        // setup capture session, not safe on multiple threads
        // dont run tasks in main queue as session.startRunning() blocking call
        sessionQueue.async {
            self.configureSession()
        }
        
        DispatchQueue.main.async {
            // show spinner if needed
            print("Spinning waiting for capture session setup")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // check session setup results
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // setup observers and start session if setup succeeded
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when user has denied access to camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK Button"), style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to Open Settings"), style: .`default`, handler: { _ in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK Button"), style: .cancel, handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Stop capture session and remove observers
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
        
        super.viewWillDisappear(animated)
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        // Change view orientation
        if let capturePreviewLayerConnection = cameraView.camPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newCaptureOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue),
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else { return }
            
            capturePreviewLayerConnection.videoOrientation = newCaptureOrientation
        }
    }
    
    /**
     * MARK: Capture Session Management
     */
    
    // Capture session result enum
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // Capture session
    private let session = AVCaptureSession()
    
    // Flag session running
    private var isSessionRunning = false
    
    private var selectSemanticSegmentationMatteTypes = [AVSemanticSegmentationMatte.MatteType]()
    
    // Session event queue
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    // Session setup result
    private var setupResult: SessionSetupResult = .success
    
    // Capture device
    @objc dynamic var captureDeviceInput: AVCaptureDeviceInput!
    
    // Camera view
    @IBOutlet weak var cameraView: CameraView!
    
    /**
     * Configure session by adding preview video input and photo output
     */
    private func configureSession() {
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        
        session.sessionPreset = .photo
        
        // Add preview video input
        do {
            var defaultCaptureDevice: AVCaptureDevice?
            
            // Pick camera available, prefer back camera
            if let dualCamDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultCaptureDevice = dualCamDevice
            }
            else if let backCamDevice = AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back) {
                defaultCaptureDevice = backCamDevice
            }
            else if let frontCamDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultCaptureDevice = frontCamDevice
            }
            
            // check device found, otherwise return
            guard let camDevice = defaultCaptureDevice else {
                print("Camera device not available")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            // save cameera device input
            let captureDeviceInput = try AVCaptureDeviceInput(device: camDevice)
            
            // add camera device input to session
            if session.canAddInput(captureDeviceInput) {
                session.addInput(captureDeviceInput)
                self.captureDeviceInput = captureDeviceInput
                
                // Dispatch preview video streaming to main queue
                // as that is where UIView can be manipulated for timely updates
                // set orientation of camera view to portrait
                DispatchQueue.main.async {
                    self.cameraView.camPreviewLayer.connection?.videoOrientation = .portrait
                }
            }
            else {
                print("Failed to add camera device input to session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch {
            print("Failed to create camera device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add audio input device in case we do live photo
        // can remove if not needed
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            }
            else {
                print("Failed to add audio device input to session")
            }
        }
        catch {
            print("Failed to create audio device input: \(error)")
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            photoOutput.isPortraitEffectsMatteDeliveryEnabled = photoOutput.isPortraitEffectsMatteDeliverySupported
            photoOutput.enabledSemanticSegmentationMatteTypes = photoOutput.availableSemanticSegmentationMatteTypes
            photoOutput.maxPhotoQualityPrioritization = .quality
            livePhotoMode = photoOutput.isLivePhotoCaptureSupported ? .on : .off
            
        }
        else {
            print("Failed to add photo output to session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
 
    /**
     * MARK: Capture photo management
     */
    
    // Capture photo output
    private let photoOutput = AVCapturePhotoOutput()
    
    // Live photo mode enum
    private enum LivePhotoMode {
        case on
        case off
    }
    
    private enum DepthDataDeliveryMode {
        case on
        case off
    }
    
    private enum PortraitEffectsMatteDeliveryMode {
        case on
        case off
    }
    
    // Live photo mode setting
    private var livePhotoMode: LivePhotoMode = .off
    
    // Photo capture delegates array
    private var inProgressPhotoCaptureDelegates = [Int64: CameraCaptureDelegate]()
            
    @IBOutlet weak var photoButton: UIButton!
    @IBOutlet weak var resumeButton: UIButton!
    
    private var depthDataDeliveryMode: DepthDataDeliveryMode = .off
    
    private var portraitEffectsMatteDeliveryMode: PortraitEffectsMatteDeliveryMode = .off
    
    private var photoQualityPrioritizationMode: AVCapturePhotoOutput.QualityPrioritization = .balanced
    
    private var inProgressLivePhotoCapturesCount = 0
    
    /**
     * Handle resume button click
     */
    @IBAction func resumeInterruptedSession(_ resumeButton: UIButton) {
        sessionQueue.async {
            self.session.startRunning()
            self.isSessionRunning = self.session.isRunning
            if !self.session.isRunning {
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to resume photo capture session", comment: "Alert message when unable to resume capture session")
                    let alertController = UIAlertController(title: "AVCame", message: message, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
            else {
                DispatchQueue.main.async {
                    self.resumeButton.isHidden = true
                }
            }
        }
    }
    
    /**
     * Handle photo button click
     */
    @IBAction func capturePhoto(_ photoButton: UIButton) {
        let videoPreviewLayerOrientation = cameraView.camPreviewLayer.connection?.videoOrientation
        
        sessionQueue.async {
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
            }
            
            var photoSettings = AVCapturePhotoSettings()
            
            // Capture heif photos when supported, Enable auto-flash and high res photos
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if self.captureDeviceInput.device.isFlashAvailable {
                photoSettings.flashMode = .auto
            }
            
            photoSettings.isHighResolutionPhotoEnabled = true
            if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
            }
            
            // Live Photo capture is not supported in movie mode
            if self.livePhotoMode == .on && self.photoOutput.isLivePhotoCaptureSupported {
                let livePhotoMovieFileName = NSUUID().uuidString
                let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
                photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
            }
            
            photoSettings.isDepthDataDeliveryEnabled = (self.depthDataDeliveryMode == .on && self.photoOutput.isDepthDataDeliveryEnabled)
            photoSettings.isPortraitEffectsMatteDeliveryEnabled = (self.portraitEffectsMatteDeliveryMode == .on && self.photoOutput.isPortraitEffectsMatteDeliveryEnabled)
            
            if photoSettings.isDepthDataDeliveryEnabled {
                if !self.photoOutput.availableSemanticSegmentationMatteTypes.isEmpty {
                    photoSettings.enabledSemanticSegmentationMatteTypes = self.selectSemanticSegmentationMatteTypes
                }
            }
            
            photoSettings.photoQualityPrioritization = self.photoQualityPrioritizationMode
            
            let captureDelegate = CameraCaptureDelegate(with: photoSettings, willCapturePhotoAnimation: {
                DispatchQueue.main.async {
                    self.cameraView.camPreviewLayer.opacity = 0
                    UIView.animate(withDuration: 0.25) {
                        self.cameraView.camPreviewLayer.opacity = 1
                    }
                }
                }, livePhotoCaptureHandler: { capturing in
                    self.sessionQueue.async {
                        if capturing {
                            self.inProgressLivePhotoCapturesCount += 1
                        }
                        else {
                            self.inProgressLivePhotoCapturesCount -= 1
                        }
                        
                        let inProgressLiveCapturesCount = self.inProgressLivePhotoCapturesCount
                        DispatchQueue.main.async {
                            if inProgressLiveCapturesCount > 0 {
                                print("Capturing Live Photos")
                            }
                            else if inProgressLiveCapturesCount == 0 {
                                print("Not capturing Live Photos")
                            }
                            else {
                                print("Error: Live Photo capture count < 0")
                            }
                        }
                    }
                    
            }, completionHandler: { captureDelegate in
                self.sessionQueue.async {
                    self.inProgressPhotoCaptureDelegates[captureDelegate.requestedPhotoSettings.uniqueID] = nil
                }
                
            }, photoProcessingHandler: { animate in
                DispatchQueue.main.async {
                    if animate {
                        print("Busy processing photo")
                    }
                    else {
                        print("Done processing photo")
                    }
                }
            })
            
            // photo output has weak ref to capture delegate, store it in array to maintain strong ref
            self.inProgressPhotoCaptureDelegates[captureDelegate.requestedPhotoSettings.uniqueID] = captureDelegate
            self.photoOutput.capturePhoto(with: photoSettings, delegate: captureDelegate)
        }
    }
    
    /**
     * MARK: AVCaptureFileOutputRecordingDelegate implementation
     */
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
    }
    
    /**
     * MARK: KVO and notifications
     *
     * Add observers for interruption events
     */
    private var keyValueObservations = [NSKeyValueObservation]()
    
    private func addObservers() {
        let keyValueObservation = session.observe(\.isRunning, options: .new) {
            _, change in
            guard let isSessionRunning = change.newValue else { return }
            
            // not needed as we don't have UI buttons to allow user to enable/disable these features
            //let isLivePhotoCaptureEnabled = self.photoOutput.isLivePhotoCaptureEnabled
            //let isDepthDeliveryDataEnabled = self.photoOutput.isDepthDataDeliveryEnabled
            //let isPortraitEffectsMatteEnabled = self.photoOutput.isPortraitEffectsMatteDeliveryEnabled
            //let isSemanticsSegmentationMatteEnabled = !self.photoOutput.enabledSemanticSegmentationMatteTypes.isEmpty
            
            DispatchQueue.main.async {
                self.photoButton.isEnabled = isSessionRunning
            }
        }
        
        keyValueObservations.append(keyValueObservation)
        
        // observe for capture system pressure events
        let systemPressureStateObservation = observe(\.captureDeviceInput.device.systemPressureState, options: .new) {
            _, change in
            guard let systemPressureState = change.newValue else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
        }
        
        keyValueObservations.append(systemPressureStateObservation)
        
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: captureDeviceInput.device)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
        
        // session can run only when app is full screen
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: session)
    }
    
    /**
     * Remove event observers
     */
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        
        keyValueObservations.removeAll()
    }
    
    /**
     * Handle capture system pressure event
     */
    private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        let pressureLevel = systemPressureState.level
        if pressureLevel == .serious || pressureLevel == .critical {
            // no change of movie frame rate as we're not capturing movies
            print("Pressure level is serious/critical")
        }
        else if pressureLevel == .shutdown {
            print("Session stopped due to shutdown system pressure level")
        }
    }
    
    /**
     * Handle subject area changes by refocusing capture device
     */
    @objc func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    /**
     * Handle session runtime error
     */
    @objc func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
        
        // restart session if media services reset
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                }
                else {
                    DispatchQueue.main.async {
                        self.resumeButton.isHidden = false
                    }
                }
            }
        }
        else {
            resumeButton.isHidden = false
        }
    }
    
    /**
     * Handle session interruption
     */
    @objc func sessionWasInterrupted(notification: NSNotification) {
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted reason: \(reason)")
            
            var showResumeButton = false
            if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
                showResumeButton = true
            }
            else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                // can show label to user
                print("Camera unavailable")
            }
            else if reason == .videoDeviceNotAvailableDueToSystemPressure {
                print("Session stopped due to shutdown system pressure level")
            }
            
            if showResumeButton {
                resumeButton.alpha = 0
                resumeButton.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.resumeButton.alpha = 1
                }
            }
        }
    }
    
    /**
     * Handle session interruption ended
     */
    @objc func sessionInterruptionEnded(notification: NSNotification) {
        print("Capture session interruption ended")
        
        if !resumeButton.isHidden {
            UIView.animate(withDuration: 0.25, animations: {self.resumeButton.alpha = 0}, completion: { _ in self.resumeButton.isHidden = true })
        }
        
        // if had camera unavailable label, hide it here
    }
    
    /**
     * Focus capture device on subject change
     */
    private func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        sessionQueue.async {
            let device = self.captureDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                // set point of interest and apply it to focus capture device
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            }
            catch {
                print("Failed to lock device for configuration: \(error)")
            }
        }
    }
}
 
