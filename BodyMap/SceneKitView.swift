//
//  SceneKitView.swift
//  ModelTest
//
//  Created by Michael Miller on 2/14/17.
//  Copyright © 2017 Michael Miller. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit

// MARK: Protocols
protocol SceneKitViewDelegate {
    func sceneViewDidBeginMoving(position: SCNVector3)
    func sceneViewItemSelected(name: String)
    func sceneViewItemDeselected()
}

// MARK: View
class SceneKitView: UIView, SCNSceneRendererDelegate, UIGestureRecognizerDelegate {
    
    // MARK: Variables
    private let delayedSelectionTime:Double = 0.333
    private let delayedDoubleTapTime:Double = 0.2
    private var singleTapAction:DispatchWorkItem! = nil
    private var doubleTapAction:DispatchWorkItem! = nil
    private var sceneIntiallyRendered:Bool = false
    private var lastPointY:Double! = nil
    public let sceneView:SCNView = SCNView()
    
    // Cameras
    var cameraOrbit = SCNNode()
    let cameraNode = SCNNode()
    let camera = SCNCamera()
    
    // MARK: Interaction Variables
    private var singlePanGesture:UIPanGestureRecognizer!
    private var doublePanGesture:UIPanGestureRecognizer!
    private var pinchGesture:UIPinchGestureRecognizer!
    private let pinchAttenuation:Double = 70.0 // 1.0: very fast - 100.0 very slow
    private let maxHeightRatioXDown:Float = -0.5
    private let maxHeightRatioXUp:Float = 0.5
    private var lastWidthRatio:Float = 0
    private var lastHeightRatio:Float = 0.2
    private var widthRatio:Float = 0
    private var heightRatio:Float = 0.2
    private let maxZoomDistance:Double = 0.8
    private let minZoomDistance:Double = 0.1
    private let animationDuration:Double = 0.33
    private var roundedRotation:Double = 0.5
    
    // Panning Variables
    private var lastAdjustWidthRatio:Float = 0
    private var lastAdjustHeightRatio:Float = 0
    private var adjustWidthRatio:Float = 0
    private var adjustHeightRatio:Float = 0
    private let maxPanDown:Float = -1.0
    private let maxPanUp:Float = 1.0
    private let maxPanLeft:Float = -0.8
    private let maxPanRight:Float = 0.8
    private var isFacingFront:Bool = true
    private var wasFacingFacingFrontLast:Bool = true
    private var lastLongPressLocation:CGPoint! = nil
    
    // Set scene
    public var scene: SCNScene? {
        didSet {
            
            // Create a camera
            camera.usesOrthographicProjection = true
            camera.orthographicScale = maxZoomDistance
            camera.zNear = 1
            camera.zFar = 100
            
            // Set position
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
            cameraNode.camera = camera
            cameraOrbit = SCNNode()
            cameraOrbit.addChildNode(cameraNode)
            scene!.rootNode.addChildNode(cameraOrbit)
            
            // Initial camera setup
            cameraOrbit.eulerAngles.y = Float(-2 * M_PI) * lastWidthRatio
            cameraOrbit.eulerAngles.x = Float(-M_PI) * lastHeightRatio
            
            // Disable default camera controls
            sceneView.allowsCameraControl = false
            
            // Set the scene
            sceneView.scene = scene
            
//            // place the camera
//            let defaults = UserDefaults.standard
//            if let defaultX = defaults.object(forKey: Constants.scenePositionX) as? Float, let defaultY = defaults.object(forKey: Constants.scenePositionY) as? Float, let defaultZ = defaults.object(forKey: Constants.scenePositionZ) as? Float, let rotationX = defaults.object(forKey: Constants.sceneRotationX) as? Float, let rotationY = defaults.object(forKey: Constants.sceneRotationY) as? Float, let rotationZ = defaults.object(forKey: Constants.sceneRotationZ) as? Float, let rotationW = defaults.object(forKey: Constants.sceneRotationW) as? Float, let fovX = defaults.object(forKey: Constants.sceneFovX) as? Double, let fovY = defaults.object(forKey: Constants.sceneFovY) as? Double {
//                sceneView.pointOfView!.position = SCNVector3(x: defaultX, y: defaultY, z: defaultZ)
//                sceneView.pointOfView!.rotation = SCNVector4(x: rotationX, y: rotationY, z: rotationZ, w: rotationW)
//                sceneView.pointOfView!.camera!.xFov = fovX
//                sceneView.pointOfView!.camera!.yFov = fovY
//            } else {
//                sceneView.pointOfView!.position = SCNVector3(x: 0, y: 0, z: 15)
//            }
        }
    }
    
    // Delegate Variable
    public var delegate: SceneKitViewDelegate? {
        didSet {
            
            // Setup Scene
            sceneView.frame.size.width = bounds.width
            sceneView.frame.size.height = bounds.height
            addSubview(sceneView)
            sceneView.delegate = self
            
            // Set colors
            backgroundColor = UIColor.clear
            sceneView.backgroundColor = UIColor.clear
            
            // Add single tap
            let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
            sceneView.addGestureRecognizer(singleTap)
            
            // Add double tap
            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
            doubleTap.numberOfTapsRequired = 2
            sceneView.addGestureRecognizer(doubleTap)
            
            // Add triple tap
            let tripleTap = UITapGestureRecognizer(target: self, action: #selector(tripleTapped))
            tripleTap.numberOfTapsRequired = 3
            sceneView.addGestureRecognizer(tripleTap)
            
            // Add long press
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed))
            longPress.numberOfTapsRequired = 1
            longPress.minimumPressDuration = 0.16
            sceneView.addGestureRecognizer(longPress)
            
            // Single pan gesture recognizer
            singlePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSinglePan))
            singlePanGesture.maximumNumberOfTouches = 1
            singlePanGesture.delegate = self
            sceneView.addGestureRecognizer(singlePanGesture)
            
            // Double pan gesture recognizer
            doublePanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDoublePan))
            doublePanGesture.minimumNumberOfTouches = 2
            doublePanGesture.maximumNumberOfTouches = 2
            doublePanGesture.delegate = self
            sceneView.addGestureRecognizer(doublePanGesture)
            
            // Pinch gesture recognizer
            pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
            doublePanGesture.minimumNumberOfTouches = 2
            doublePanGesture.maximumNumberOfTouches = 2
            pinchGesture.delegate = self
            sceneView.addGestureRecognizer(pinchGesture)
        }
    }
    
    // MARK: Init
    func setScene(delegate: SceneKitViewDelegate, scene: SCNScene) {
        self.delegate = delegate
        self.scene = scene
    }
    
    // MARK: Handle Touches
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        // Check for SceneKit view
        if (!subviews.contains(sceneView)) {
            return
        }
        
        // Handle Touches
        if let d = delegate {
            d.sceneViewDidBeginMoving(
                position: sceneView.pointOfView!.position)
        }
    }
    
    // MARK: Handle Single Pan
    @objc private func handleSinglePan(gesture: UIPanGestureRecognizer) {
        
        // Get translation
        // ** the distance that the gesture has moved in view
        let translation = gesture.translation(in: gesture.view!)
        
        // Save ratios for later
        widthRatio = Float(translation.x) / Float(gesture.view!.frame.size.width) + lastWidthRatio
        heightRatio = Float(translation.y) / Float(gesture.view!.frame.size.height) + lastHeightRatio
        
        // Get panning state
        switch gesture.state {
            
        case .began:
            break
            
        case .changed:
            
            // Up limitation
            if (heightRatio >= maxHeightRatioXUp) {
                heightRatio = maxHeightRatioXUp
            }
            
            // Down limitation
            if (heightRatio <= maxHeightRatioXDown) {
                heightRatio = maxHeightRatioXDown
            }
            
            // Set camera position
            cameraOrbit.eulerAngles.y = Float(-2 * M_PI) * widthRatio
            cameraOrbit.eulerAngles.x = Float(-M_PI) * heightRatio
            
            // Save current rotation
            roundedRotation = Double((widthRatio - round(widthRatio)) + 0.5)
            
            // Check for rotation
            if (roundedRotation < 0.25 || roundedRotation > 0.75) {
                isFacingFront = false
            } else {
                isFacingFront = true
            }
            
        case .ended:
            
            // Save ratios
            lastWidthRatio = widthRatio
            lastHeightRatio = heightRatio
            
            // Check if rotation was changed
            if (wasFacingFacingFrontLast != isFacingFront) {
                lastAdjustWidthRatio = -lastAdjustWidthRatio
            }
            
            // Save rotation side
            wasFacingFacingFrontLast = isFacingFront
            
        default:
            break
        }
    }
    
    // MARK: Handle Double Pan
    @objc private func handleDoublePan(gesture: UIPanGestureRecognizer) {
        
        // Get translation
        let translation = gesture.translation(in: gesture.view!)
        
        // Handle panning
        panXY(gesture: gesture, translation: translation)
    }
    
    // Long Press Gesture
    @objc private func longPressed(gesture: UIGestureRecognizer) {
        
        // Cancel Single Tap Action
        if let tapAction = singleTapAction {
            tapAction.cancel()
        }
        
        // Cancel Double Tap Action
        if let doubleTapAction = doubleTapAction {
            doubleTapAction.cancel()
        }
        
        // Get translation
        let location = gesture.location(in: sceneView)
        
        // Set location for nil
        if (lastLongPressLocation == nil) {
            lastLongPressLocation = location
        }
        
        // Get translation
        let translation = CGPoint(x: location.x - lastLongPressLocation.x, y: location.y - lastLongPressLocation.y)
        
        // Handle panning
        panXY(gesture: gesture, translation: translation)
    }
    
    // MARK: Pan the view X and Y
    private func panXY(gesture: UIGestureRecognizer, translation: CGPoint) {
        
        // Get ratios
        adjustWidthRatio = Float(translation.x) / Float(sceneView.frame.size.height) + lastAdjustWidthRatio
        adjustHeightRatio = Float(translation.y) / Float(sceneView.frame.size.height) + lastAdjustHeightRatio
        
        // Get panning state
        switch gesture.state {
            
        case .began:
            break
            
        case .changed:
            
            // Get factors
            var zoomRatio = 1 + Float(camera.orthographicScale)
            let upDownFactor = adjustHeightRatio * zoomRatio
            let leftRightFactor = adjustWidthRatio * zoomRatio
            
            // Up limiation
            if (upDownFactor >= maxPanUp) {
                zoomRatio = 1
                adjustHeightRatio = maxPanUp
            }
            
            // Down limiation
            if (upDownFactor <= maxPanDown) {
                zoomRatio = 1
                adjustHeightRatio = maxPanDown
            }
            
            // Right limiation
            if (leftRightFactor >= maxPanRight) {
                zoomRatio = 1
                adjustWidthRatio = maxPanRight
            }
            
            // Left limiation
            if (leftRightFactor <= maxPanLeft) {
                zoomRatio = 1
                adjustWidthRatio = maxPanLeft
            }
            
            // Set position of camera
            cameraOrbit.position.y = adjustHeightRatio * (1 + Float(camera.orthographicScale))
            
            // Check for rotation
            if (roundedRotation < 0.25 || roundedRotation > 0.75) {
                cameraOrbit.position.x = adjustWidthRatio * zoomRatio
            } else {
                cameraOrbit.position.x = -adjustWidthRatio * zoomRatio
            }
            
        case .ended:
            
            // Save ratios
            lastAdjustWidthRatio = adjustWidthRatio
            lastAdjustHeightRatio = adjustHeightRatio
            
            // Reset last location
            lastLongPressLocation = nil
            
        default:
            break
        }
    }
    
    // MARK: Handle Pinch
    @objc private func handlePinch(gesture: UIPinchGestureRecognizer) {
        
        // Get velocity
        let pinchVelocity = Double(gesture.velocity)
        
        // Pinch threshold
        let pinchThreshold = 0.4
        
        // Watch for threshold
        if (pinchVelocity > pinchThreshold || pinchVelocity < -pinchThreshold) {
            
            // Subtract velocity / pin factor
            camera.orthographicScale -= (pinchVelocity / pinchAttenuation)
            
            // Set min pinch
            if (camera.orthographicScale <= minZoomDistance) {
                camera.orthographicScale = minZoomDistance
            }
            
            // Set max pinch
            if (camera.orthographicScale >= maxZoomDistance) {
                camera.orthographicScale = maxZoomDistance
            }
        }
    }
    
    // Single Tap Gesture
    @objc private func singleTapped(gesture: UIGestureRecognizer) {
        
        // Check what nodes are tapped
        let p = gesture.location(in: self.sceneView)
        let hitResults = self.sceneView.hitTest(p, options: [:])
        
        // Call single tap action
        singleTapAction = DispatchWorkItem {
            
            // Check that we clicked on at least one object
            if (hitResults.count > 0) {
                
                // retrieved the first clicked object
                let result: AnyObject = hitResults[0]
                let currentNode: SCNNode = result.node
                
                // Call delegate for item
                if let d = self.delegate {
                    d.sceneViewItemSelected(name: result.node.name!)
                }
                
                // Begin Animation
                SCNTransaction.begin()
                SCNTransaction.animationDuration = self.animationDuration
                
                // Loop Child nodes
                self.sceneView.scene!.rootNode.enumerateChildNodes { (node, stop) -> Void in

                    // Set opacity
                    if let name = node.name {
                        if (name == Constants.skeletal || name == Constants.spot || node.name == currentNode.name) {
                            node.opacity = 1
                        } else {
                            node.opacity = 0.2
                        }
                    }
                }
                
                // End
                SCNTransaction.commit()

            } else {
                
                // Loop Child nodes
                SCNTransaction.begin()
                SCNTransaction.animationDuration = self.animationDuration
                self.sceneView.scene!.rootNode.enumerateChildNodes { (node, stop) -> Void in
                    node.opacity = 1
                }
                SCNTransaction.commit()
                
                // Call delegate for deselection
                if let d = self.delegate {
                    d.sceneViewItemDeselected()
                }
            }
        }
        
        // Perform delayed event
        DispatchQueue.main.asyncAfter(deadline: .now() + delayedSelectionTime, execute: singleTapAction)
    }
    
    // Double Tap Gesture
    @objc private func doubleTapped(gesture: UIGestureRecognizer) {
        
        // Cancel Single Tap Action
        if let tapAction = singleTapAction {
            tapAction.cancel()
        }
        
        // Save double tap action
        doubleTapAction = DispatchWorkItem {
        
            // Zoom factor
            let zoomFactor = 0.1
            
            // Calc what change would be
            let calculatedChange = self.camera.orthographicScale - zoomFactor
            
            // Change camera scale
            if (calculatedChange > self.minZoomDistance) {
                
                // Begin Animation
                SCNTransaction.begin()
                SCNTransaction.animationDuration = self.animationDuration
                
                // Perform Change
                self.camera.orthographicScale -= zoomFactor
                
                // End
                SCNTransaction.commit()
                
            } else if (calculatedChange <= self.minZoomDistance) {
                
                // Begin Animation
                SCNTransaction.begin()
                SCNTransaction.animationDuration = self.animationDuration
                
                // Perform Change
                self.camera.orthographicScale = self.minZoomDistance
                
                // End
                SCNTransaction.commit()
            }
        }
        
        // Perform delayed event
        DispatchQueue.main.asyncAfter(deadline: .now() + delayedDoubleTapTime, execute: doubleTapAction)
    }
    
    // Triple Tap Gesture
    @objc private func tripleTapped(gesture: UIGestureRecognizer) {
        
        // Cancel Single Tap Action
        if let singleTapAction = singleTapAction {
            singleTapAction.cancel()
        }
        
        // Cancel Single Tap Action
        if let doubleTapAction = doubleTapAction {
            doubleTapAction.cancel()
        }
        
        // Zoom factor
        let zoomFactor = 0.1
        
        // Calc what change would be
        let calculatedChange = camera.orthographicScale - zoomFactor
        
        // Change camera scale
        if (calculatedChange < maxZoomDistance) {
            
            // Begin Animation
            SCNTransaction.begin()
            SCNTransaction.animationDuration = animationDuration
            
            // Perform Change
            camera.orthographicScale += zoomFactor
            
            // End
            SCNTransaction.commit()
            
        } else if (calculatedChange >= maxZoomDistance) {
            
            // Begin Animation
            SCNTransaction.begin()
            SCNTransaction.animationDuration = animationDuration
            
            // Perform Change
            camera.orthographicScale = maxZoomDistance
            
            // End
            SCNTransaction.commit()
        }
    }
    
    // MARK: Handle Multiple Gestures
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false // for now
    }
    
    // MARK: SceneKit Render Delegates
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        
        // Check if view has rendered before
        if (!sceneIntiallyRendered) {
            sceneIntiallyRendered = true
        } else {
            
            // Point of view
            UserDefaults.standard.set(sceneView.pointOfView!.position.x, forKey: Constants.scenePositionX)
            UserDefaults.standard.set(sceneView.pointOfView!.position.y, forKey: Constants.scenePositionY)
            UserDefaults.standard.set(sceneView.pointOfView!.position.z, forKey: Constants.scenePositionZ)
            
            // Rotation
            UserDefaults.standard.set(sceneView.pointOfView!.rotation.x, forKey: Constants.sceneRotationX)
            UserDefaults.standard.set(sceneView.pointOfView!.rotation.y, forKey: Constants.sceneRotationY)
            UserDefaults.standard.set(sceneView.pointOfView!.rotation.z, forKey: Constants.sceneRotationZ)
            UserDefaults.standard.set(sceneView.pointOfView!.rotation.w, forKey: Constants.sceneRotationW)
            
            // Field of view
            UserDefaults.standard.set(sceneView.pointOfView!.camera!.xFov, forKey: Constants.sceneFovX)
            UserDefaults.standard.set(sceneView.pointOfView!.camera!.yFov, forKey: Constants.sceneFovY)
        }
        
        // Loop Child nodes
        scene.rootNode.enumerateChildNodes { (node, stop) -> Void in
            
            // Set opacity
            if let name = node.name {
                if (name.contains("Skeletal")) {
                    node.isHidden = true
                } else {
                    node.isHidden = false
                }
            }
        }
    }

}
