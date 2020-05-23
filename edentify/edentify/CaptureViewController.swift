//
//  CaptureViewController.swift
//  edentify
//
//  Created by Eddie Sananikone on 5/17/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import UIKit
import AVKit
import Vision

class CaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // Capture view content
    @IBOutlet weak var capturePreviewView: UIView!
    
    // AVCapture data
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var captureOutput: AVCaptureVideoDataOutput?
    var captureOutputQueue: DispatchQueue?
    
    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()
    
    // Layer UI for Vision results
    var rootLayer: CALayer?
    var detectionOverlayLayer: CALayer?
    var detectedFaceRectangleShapeLayer: CAShapeLayer?
    var detectedFaceLandmarksShapeLayer: CAShapeLayer?
    
    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
    private var trackingRequests: [VNTrackingRequest]?
    
    lazy var sequenceReqestHandler = VNSequenceRequestHandler()
    
    // MARK: UIViewController overrides
    
    /**
     * Setup session, vision request, and start capture
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup session
        self.session = self.setupAVCaptureSession()
        
        // prepare vision
        self.prepareVisionRequest()
        
        // start capture session
        self.session?.startRunning()
    }
    
    /**
     * Handle memory warning
     */
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    /**
     * Portrait orientation only
     */
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    // MARK: AVCapture Setup
    
    /**
     * Setup capture session
     */
    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        do {
            let inputDevice = try self.configureFrontCamera(for: captureSession)
            self.configureCaptureOutput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
            self.designatePreviewLayer(for: captureSession)
            return captureSession
        }
        catch let executionError as NSError {
            self.presentError(executionError)
        }
        catch {
            self.presentErrorAlert(message: "An unexpected failure occurred")
        }
        
        self.teardownAVCapture()
        
        return nil
    }
    
    /**
     * Configure capture resolution
     */
    fileprivate func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            
            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    /**
     * Configure front camera for capture
     */
    fileprivate func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                
                if let highestResolution = self.highestResolution420Format(for: device) {
                    try device.lockForConfiguration()
                    device.activeFormat = highestResolution.format
                    device.unlockForConfiguration()
                    
                    return (device, highestResolution.resolution)
                }
            }
        }
        
        throw NSError(domain: "CaptureViewController", code: 1, userInfo: nil)
    }
    
    /**
     * Configure capture output and serial dispatch queue
     */
    fileprivate func configureCaptureOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        let captureOutput = AVCaptureVideoDataOutput()
        captureOutput.alwaysDiscardsLateVideoFrames = true
        
        // create serial dispatch queue for order of video frames
        let captureOutputQueue = DispatchQueue(label: "Edentify")
        captureOutput.setSampleBufferDelegate(self, queue: captureOutputQueue)
        
        if captureSession.canAddOutput(captureOutput) {
            captureSession.addOutput(captureOutput)
        }
        
        captureOutput.connection(with: .video)?.isEnabled = true
        
        if let captureConnection = captureOutput.connection(with: AVMediaType.video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
        
        self.captureOutput = captureOutput
        self.captureOutputQueue = captureOutputQueue
        
        self.captureDevice = inputDevice
        self.captureDeviceResolution = resolution
    }
    
    /**
     * Designate preview layer for capture
     */
    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let capturePreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = capturePreviewLayer
        
        capturePreviewLayer.name = "CameraPreview"
        capturePreviewLayer.backgroundColor = UIColor.black.cgColor
        capturePreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        if let previewRootLayer = self.capturePreviewView?.layer {
            self.rootLayer = previewRootLayer
            
            previewRootLayer.masksToBounds = true
            capturePreviewLayer.frame = previewRootLayer.bounds
            previewRootLayer.addSublayer(capturePreviewLayer)
        }
    }
    
    /**
     * Cleanup capture resources
     */
    fileprivate func teardownAVCapture() {
        self.captureOutput = nil
        self.captureOutputQueue = nil
        
        if let previewLayer = self.previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
    
    /**
     * Error handlers
     */
    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }
    
    fileprivate func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
    
    /**
     * Handle device orientation and EXIF
     */
    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
        case .landscapeLeft:
            return .downMirrored
        case .landscapeRight:
            return .upMirrored
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    // MARK: Vision requests
    
    /**
     * Prepare vision request
     */
    fileprivate func prepareVisionRequest() {
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest, let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
            }
            
            DispatchQueue.main.async {
                // add observations to tracking list
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                
                self.trackingRequests = requests
            }
        })
        
        // start detection, find face and track
        self.detectionRequests = [faceDetectionRequest]
        
        self.sequenceReqestHandler = VNSequenceRequestHandler()
        
        self.setupVisionDrawingLayers()
    }
    
    // MARK: Draw vision observations
    
    /**
     * setup drawing layers
     */
    fileprivate func setupVisionDrawingLayers() {
        let captureDeviceResolution = self.captureDeviceResolution
        
        let captureDeviceBounds = CGRect(x: 0, y: 0, width: captureDeviceResolution.width, height: captureDeviceResolution.height)
        
        let captureDeviceBoundsCenterPoint = CGPoint(x: captureDeviceBounds.midX, y: captureDeviceBounds.midY)
        
        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)
        
        guard let rootLayer = self.rootLayer else {
            self.presentErrorAlert(message: "View was not properly initialized")
            return
        }
        
        let overlayLayer = CALayer()
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = normalizedCenterPoint
        overlayLayer.bounds = captureDeviceBounds
        overlayLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        
        let faceRectangleShapeLayer = CAShapeLayer()
        faceRectangleShapeLayer.name = "RectangleOutlineLayer"
        faceRectangleShapeLayer.bounds = captureDeviceBounds
        faceRectangleShapeLayer.anchorPoint = normalizedCenterPoint
        faceRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
        faceRectangleShapeLayer.fillColor = nil
        faceRectangleShapeLayer.strokeColor = UIColor.blue.withAlphaComponent(0.7).cgColor
        faceRectangleShapeLayer.lineWidth = 5
        faceRectangleShapeLayer.shadowOpacity = 0.7
        faceRectangleShapeLayer.shadowRadius = 5
        
        let faceLandmarksShapeLayer = CAShapeLayer()
        faceLandmarksShapeLayer.name = "FaceLandmarksLayer"
        faceLandmarksShapeLayer.bounds = captureDeviceBounds
        faceLandmarksShapeLayer.anchorPoint = normalizedCenterPoint
        faceLandmarksShapeLayer.position = captureDeviceBoundsCenterPoint
        faceLandmarksShapeLayer.fillColor = nil
        faceLandmarksShapeLayer.strokeColor = UIColor.red.withAlphaComponent(0.7).cgColor
        faceLandmarksShapeLayer.lineWidth = 3
        faceLandmarksShapeLayer.shadowOpacity = 0.7
        faceLandmarksShapeLayer.shadowRadius = 5
        
        overlayLayer.addSublayer(faceRectangleShapeLayer)
        faceRectangleShapeLayer.addSublayer(faceLandmarksShapeLayer)
        rootLayer.addSublayer(overlayLayer)
        
        self.detectionOverlayLayer = overlayLayer
        self.detectedFaceRectangleShapeLayer = faceRectangleShapeLayer
        self.detectedFaceLandmarksShapeLayer = faceLandmarksShapeLayer
        
        self.updateLayerGeometry()
    }
    
    fileprivate func updateLayerGeometry() {
        guard let overlayLayer = self.detectionOverlayLayer,
            let rootLayer = self.rootLayer,
            let previewLayer = self.previewLayer
            else {
                return
        }
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        
        // Rotate layer to screen orientation
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
        case .landscapeRight:
            rotation = -90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
        default:
            rotation = 0
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        }
        
        // scale and mirror image to ensure upright presentation
        let affineTransform = CGAffineTransform(rotationAngle: radiansForDegrees(rotation)).scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)
        
        // cover entire screen UI
        let rootLayerBounds = rootLayer.bounds
        overlayLayer.position = CGPoint(x: rootLayerBounds.midX, y: rootLayerBounds.midY)
    }
    
    fileprivate func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D, to path: CGMutablePath, applying affineTransform: CGAffineTransform, closingWhenComplete closePath: Bool) {
        let pointCount = landmarkRegion.pointCount
        if pointCount > 1 {
            let points: [CGPoint] = landmarkRegion.normalizedPoints
            path.move(to: points[0], transform: affineTransform)
            path.addLines(between: points, transform: affineTransform)
            if closePath {
                path.addLine(to: points[0], transform: affineTransform)
                path.closeSubpath()
            }
        }
    }
    
    fileprivate func addIndicators(to faceRectanglePath: CGMutablePath, faceLandmarksPath: CGMutablePath, for faceObservation: VNFaceObservation) {
        let displaySize = self.captureDeviceResolution
        
        let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
        faceRectanglePath.addRect(faceBounds)
        
        if let landmarks = faceObservation.landmarks {
            // Landmarks relative to face bounds
            let affineTransform = CGAffineTransform(translationX: faceBounds.origin.x, y: faceBounds.origin.y).scaledBy(x: faceBounds.size.width, y: faceBounds.size.height)
            
            // treat eyebrows and lines as open-ended regions when drawing paths
            let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
                landmarks.leftEyebrow,
                landmarks.rightEyebrow,
                landmarks.faceContour,
                landmarks.noseCrest,
                landmarks.medianLine]
            for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
                self.addPoints(in: openLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: false)
            }
            
            // draw eyes, lips, and nose as closed regions
            let closedLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
                landmarks.leftEye,
                landmarks.rightEye,
                landmarks.outerLips,
                landmarks.innerLips,
                landmarks.nose]
            for closedLandmarkRegion in closedLandmarkRegions where closedLandmarkRegion != nil {
                self.addPoints(in: closedLandmarkRegion!, to: faceLandmarksPath, applying: affineTransform, closingWhenComplete: true)
            }
        }
    }
    
    /**
     * Draw paths
     */
    fileprivate func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
        guard let faceRectangleShapeLayer = self.detectedFaceRectangleShapeLayer,
            let faceLandmarksShapeLayer = self.detectedFaceLandmarksShapeLayer
            else {
                return
        }
        
        CATransaction.begin()
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let faceRectanglePath = CGMutablePath()
        let faceLandmarksPath = CGMutablePath()
        
        for faceObservation in faceObservations {
            self.addIndicators(to: faceRectanglePath, faceLandmarksPath: faceLandmarksPath, for: faceObservation)
        }
        
        faceRectangleShapeLayer.path = faceRectanglePath
        faceLandmarksShapeLayer.path = faceLandmarksPath
        
        self.updateLayerGeometry()
        
        CATransaction.commit()
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate implementation
    
    /**
     * Handle receive of sample buffer
     */
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain CVPixelBuffer for current output frame.")
            return
        }
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            // no tracking object detected, so perform initial detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                
                try imageRequestHandler.perform(detectRequests)
            }
            catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
            
            return
        }
        
        do {
            try self.sequenceReqestHandler.perform(requests, on: pixelBuffer, orientation: exifOrientation)
        }
        catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        // setup next round of tracking
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                }
                else {
                    trackingRequest.isLastFrame = true
                }
                
                newTrackingRequests.append(trackingRequest as! VNTrackObjectRequest)
            }
        }
        
        self.trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            // nothing to track, abort
            return
        }
        
        // perform face landmark tracing on detected faces
        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        
        // perform landmark detection on tracked faces
        for trackingRequest in newTrackingRequests {
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
                }
                
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                    let results = landmarksRequest.results as? [VNFaceObservation] else {
                        return
                }
                
                // perform all ui updates on main queue, not on background queue which this handler is being called
                DispatchQueue.main.async {
                    self.drawFaceObservations(results)
                }
            })
            
            guard let trackingResults = trackingRequest.results else {
                return
            }
            
            guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
                return
            }
            
            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
            faceLandmarksRequest.inputFaceObservations = [faceObservation]
            
            // continue to track detected facial landmarks
            faceLandmarkRequests.append(faceLandmarksRequest)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform(faceLandmarkRequests)
            }
            catch let error as NSError {
                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
            }
        }
    }
}
