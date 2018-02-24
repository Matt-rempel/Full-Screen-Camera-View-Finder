//
//  ViewController.swift
//  Full Screen Camera View Finder
//
//  Created by Matthew Rempel on 2018-02-24.
//  Copyright © 2018 Matthew Rempel. All rights reserved.
//

import UIKit
import AVFoundation


class ViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var pinch:UIPinchGestureRecognizer!
    var captureDevice:AVCaptureDevice!
    var factor:CGFloat!
    var pivotPinchScale:CGFloat = 1.0
    var prevPinchScale:CGFloat = 0.0
    var subFactor:CGFloat = 0.0
    
    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 1000.0
    var lastZoomFactor: CGFloat = 1.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        captureDevice = AVCaptureDevice.default(for: AVMediaType.video)!
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            previewView.layer.addSublayer(videoPreviewLayer!)
            
            captureSession?.startRunning()
            
        } catch {
            print(error)
        }
        
        pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinched))
        pinch.delegate = self as? UIGestureRecognizerDelegate
        previewView.addGestureRecognizer(pinch)
        
        
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func prefersHomeIndicatorAutoHidden() -> Bool{
        return true
    }
    
    override var shouldAutorotate: Bool{
        return true
    }
    
    
    
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(
            alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) in
                let deltaTransform = coordinator.targetTransform
                let deltaAngle = atan2f(Float(deltaTransform.b), Float(deltaTransform.a))
                var currentRotation : Float = ((self.previewView!.layer.value(forKeyPath: "transform.rotation.z") as AnyObject).floatValue)!
                
                currentRotation += -1 * deltaAngle + 0.0001;
                self.previewView!.layer.setValue(currentRotation, forKeyPath: "transform.rotation.z")
                self.previewView!.layer.frame = self.view.bounds
        },
            completion:
            { (UIViewControllerTransitionCoordinatorContext) in
                // Integralize the transform to undo the extra 0.0001 added to the rotation angle.
                var currentTransform : CGAffineTransform = self.previewView!.transform
                currentTransform.a = round(currentTransform.a)
                currentTransform.b = round(currentTransform.b)
                currentTransform.c = round(currentTransform.c)
                currentTransform.d = round(currentTransform.d)
                self.previewView!.transform = currentTransform
        })
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchPoint = touches.first! as UITouch
        let screenSize = previewView.bounds.size
        let focusPoint = CGPoint(x: touchPoint.location(in: previewView).y / screenSize.height, y: 1.0 - touchPoint.location(in: previewView).x / screenSize.width)
        
        if let device = captureDevice {
            do {
                
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = AVCaptureDevice.FocusMode.autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
                }
                device.unlockForConfiguration()
                
            } catch {
                // Handle errors here
            }
        }
    }
    
    @objc func pinched(){
        captureDevice = AVCaptureDevice.default(for: AVMediaType.video)!
        
        let device = captureDevice!
        
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }
        
        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)
        
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
        default: break
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

