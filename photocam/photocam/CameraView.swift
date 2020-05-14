//
// NOTE: The code derived here was pulled from Apple's AVCamBuildingACameraApp sample
//       Only minor updates were made to extract only photo capture and simplication
//       of UI.  Doing so allowed understanding of the code involved to make use of camera
//       capture of photos, and storage to Photo Library.
//
//  CameraView.swift
//
//  Created by Eddie Sananikone on 5/2/20.
//  Copyright © 2020 Eddie Sananikone. All rights reserved.
//

import UIKit
import AVFoundation

class CameraView : UIView {
    
    var camPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer type for layer")
        }
        
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return camPreviewLayer.session
        }
        
        set {
            camPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
}
