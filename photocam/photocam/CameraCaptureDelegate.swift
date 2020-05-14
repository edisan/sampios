//
// NOTE: The code derived here was pulled from Apple's AVCamBuildingACameraApp sample
//       Only minor updates were made to extract only photo capture and simplication
//       of UI.  Doing so allowed understanding of the code involved to make use of camera
//       capture of photos, and storage to Photo Library.
//
//  CameraCaptureDelegate.swift
//
//  Created by Eddie Sananikone on 5/2/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import AVFoundation
import Photos

class CameraCaptureDelegate: NSObject {
    
    // Requested Photo settings
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    // Function handling photo animation
    private let willCapturePhotoAnimation: () -> Void
    
    // Function handling live photo
    private let livePhotoCaptureHandler: (Bool) -> Void
    
    // Context
    lazy var context = CIContext()
    
    // Function handling photo capture completion
    private let completionHandler: (CameraCaptureDelegate) -> Void
    
    // Function handling photo processing
    private let photoProcessingHandler: (Bool) -> Void
    
    // Photo data
    private var photoData: Data?
    
    // Live Photo Movie URL
    private var livePhotoCompanionMovieURL: URL?
    
    // Portrait effects matte data (faces)
    private var portraitEffectsMatteData: Data?
    
    // Semantic segmentation matte data
    private var semanticSegmentationMatteDataArray = [Data]()
    
    // Photo processing time
    private var maxPhotoProcessingTime: CMTime?
    
    /**
     * Initialization
     */
    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         willCapturePhotoAnimation: @escaping () -> Void,
         livePhotoCaptureHandler: @escaping (Bool) -> Void,
         completionHandler: @escaping (CameraCaptureDelegate) -> Void,
         photoProcessingHandler: @escaping (Bool) -> Void) {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.livePhotoCaptureHandler = livePhotoCaptureHandler
        self.completionHandler = completionHandler
        self.photoProcessingHandler = photoProcessingHandler
    }
    
    /**
     * didFinish event handler
     */
    private func didFinish() {
        if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
            if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath) {
                do {
                    try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
                }
                catch {
                    print("Failed to remove file at url: \(livePhotoCompanionMoviePath)")
                }
            }
        }
        
        completionHandler(self)
    }
}

extension CameraCaptureDelegate: AVCapturePhotoCaptureDelegate {
    
    /**
     * WillBeginCapture event, before shutter sound
     */
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if resolvedSettings.livePhotoMovieDimensions.width > 0 && resolvedSettings.livePhotoMovieDimensions.height > 0 {
            livePhotoCaptureHandler(true)
        }
        
        maxPhotoProcessingTime = resolvedSettings.photoProcessingTimeRange.start +
            resolvedSettings.photoProcessingTimeRange.duration
    }
    
    /**
     * WillCapturePhoto event, after shutter sound
     */
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
        
        guard let maxPhotoProcessingTime =  maxPhotoProcessingTime else {
            return
        }
        
        // show spinner if processing time > 1 second
        let oneSecond = CMTime(seconds: 1, preferredTimescale: 1)
        if maxPhotoProcessingTime > oneSecond {
            photoProcessingHandler(true)
        }
    }
    
    /**
     * DidCapturePhoto event, photo captured
     */
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // May not need to implement
    }
    
    /**
     * DidFinishProcessingPhoto event, after depth and effects matte
     */
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
        }
        else {
            photoData = photo.fileDataRepresentation()
        }
        
        // portrait effects matte generated if face detected
        if var portraitEffectsMatte = photo.portraitEffectsMatte {
            if let orientation = photo.metadata[ String(kCGImagePropertyOrientation) ] as? UInt32 {
                portraitEffectsMatte = portraitEffectsMatte.applyingExifOrientation(CGImagePropertyOrientation(rawValue: orientation)!)
            }
            
            let portraitEffectsMattePixelBuffer = portraitEffectsMatte.mattingImage
            let portraitEffectsMatteImage = CIImage(cvImageBuffer: portraitEffectsMattePixelBuffer, options: [.auxiliaryPortraitEffectsMatte: true])
            guard let perceptualColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                portraitEffectsMatteData = nil
                return
            }
            
            portraitEffectsMatteData = context.heifRepresentation(of: portraitEffectsMatteImage, format: .RGBA8, colorSpace: perceptualColorSpace, options: [.portraitEffectsMatteImage: portraitEffectsMatteImage])
        }
        else {
            portraitEffectsMatteData = nil
        }
        
        // handle matte data
        for semanticSegmentationType in output.enabledSemanticSegmentationMatteTypes {
            handleMatteData(photo, ssmType: semanticSegmentationType)
        }
    }
    
    /**
     * DidFinishRecordingLive event, end of short movie capture
     */
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        livePhotoCaptureHandler(false)
    }
    
    /**
     * DidFinishingProcessingLive event, movie written to disk and ready for consumption
     */
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            print("Error processing Live Photo companion movie: \(String(describing: error))")
            return
        }
        
        livePhotoCompanionMovieURL = outputFileURL
    }
    
    /**
     * DidFinishCapture event, last event, end of capture for single photo
     */
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            didFinish()
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            didFinish()
            return
        }
        
        // Save photos to Photo Library
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue}
                    creationRequest.addResource(with: .photo, data: photoData, options: options)
                    
                    if let livePhotoCompanionMovieURL = self.livePhotoCompanionMovieURL {
                        let livePhotoCompanionMovieFileOptions = PHAssetResourceCreationOptions()
                        livePhotoCompanionMovieFileOptions.shouldMoveFile = true
                        creationRequest.addResource(with: .pairedVideo, fileURL: livePhotoCompanionMovieURL, options: livePhotoCompanionMovieFileOptions)
                    }
                    
                    // save portrait effects matte to Photo Library only if generated
                    if let portraitEffectsMatteData = self.portraitEffectsMatteData {
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo, data: portraitEffectsMatteData, options: nil)
                    }
                    
                    // save segmentation data to Photo Library only if generated
                    for semanticsSegmentationMatteData in self.semanticSegmentationMatteDataArray {
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo, data: semanticsSegmentationMatteData, options: nil)
                    }
                }, completionHandler: { _, error in
                    if let error = error {
                        print("Error occurred while saving photo to Phot Library: \(error)")
                    }
                    
                    self.didFinish()
                })
            }
            else {
                self.didFinish()
            }
        }
    }
    
    /**
     * Handle matte data
     */
    func handleMatteData(_ photo: AVCapturePhoto, ssmType: AVSemanticSegmentationMatte.MatteType) {
        // Find semantic segmentation matte image for type
        guard var segmentationMatte = photo.semanticSegmentationMatte(for: ssmType) else { return }
        
        // apply photo orientation to matte image
        if let orientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
            let exifOrientation = CGImagePropertyOrientation(rawValue: orientation) {
            segmentationMatte = segmentationMatte.applyingExifOrientation(exifOrientation)
        }
        
        var imageOption: CIImageOption!
        
        switch ssmType {
        case .hair:
            imageOption = .auxiliarySemanticSegmentationHairMatte
        case .skin:
            imageOption = .auxiliarySemanticSegmentationSkinMatte
        case .teeth:
            imageOption = .auxiliarySemanticSegmentationTeethMatte
        default:
            print("Semantic segmentation type not supported")
            return
        }
        
        guard let perceptualColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        
        // create new CIImage from matte buffer
        let ciImage = CIImage(cvImageBuffer: segmentationMatte.mattingImage, options: [imageOption: true,
                                                                                       .colorSpace: perceptualColorSpace])
        
        // get HEIF representation of image
        guard let imageData = context.heifRepresentation(of: ciImage, format: .RGBA8, colorSpace: perceptualColorSpace, options: [.depthImage: ciImage]) else { return }
        
        // add image data to SSM data array for write to photo library
        semanticSegmentationMatteDataArray.append(imageData)
    }
}
