//
//  ViewController.swift
//  Soccer
//
//  Created by User on 3/30/18.
//  Copyright © 2018 Bryce Gattis. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

enum BodyType:Int {
    case box = 1
    case ball = 2
}



class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate, ARSessionDelegate {
    
    @IBOutlet weak var ScoreLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    
    var Score : Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("Print this string")
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        
        Score = 0
        // Show statistics such as fps and timing information
        showWorldOrigin();
        self.sceneView.autoenablesDefaultLighting = true
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!

        //Set the scene to the view
        //sceneView.scene = scene
        
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if(contact.nodeA.physicsBody?.categoryBitMask == BodyType.box.rawValue && contact.nodeB.physicsBody?.categoryBitMask == BodyType.ball.rawValue) {
            print("The collision happened")
            contact.nodeB.removeFromParentNode()
            Score = Score + 1
        }
    }
    @IBAction func add(_ sender: Any) {
        let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.1))
        sphereNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "art.scnassets/soccerTexture.png")
        let upSwipeGesture = UIPanGestureRecognizer(target: self, action: #selector(ViewController.SwipeSelector));
        
        sceneView.addGestureRecognizer(upSwipeGesture)
        //var cameraTransform = sceneView.session.currentFrame?.camera.transform
        sphereNode.position = SCNVector3Make(0,0,-0.5)
        print(sphereNode.position)
        //sceneView.scene.rootNode.addChildNode(sphereNode)
        sphereNode.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: nil)
        sphereNode.physicsBody?.isAffectedByGravity = false
        sphereNode.physicsBody?.mass = 0.5
        sphereNode.physicsBody?.categoryBitMask = BodyType.ball.rawValue
        sphereNode.physicsBody?.collisionBitMask = BodyType.box.rawValue
        sphereNode.physicsBody?.contactTestBitMask = BodyType.box.rawValue
        sceneView.pointOfView?.addChildNode(sphereNode)
        
    }
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        ScoreLabel.text = String(Score)
    }
    
    @objc func SwipeSelector(sender: UIPanGestureRecognizer)
    {
        
        let location = sender.location(in: sceneView)
        //print (sender.translation(in: sceneView))
        print (sender.velocity(in: sceneView))
        if (sender.state == .ended) {
            print("Ended")
            let hitResults = sceneView.hitTest(location, options: nil)
            if hitResults.count > 0 {
                let result = hitResults[0]
                let node = result.node
                //let translation = sender.velocity(in: sceneView)
                //print(translation)
                //let dx = translation.x
                //let dy = translation.y
                let original = SCNVector3(x: -20, y:0, z: -20)
                let force = simd_make_float4(original.x, original.y, original.z, 0)
                let rotatedForce = simd_mul((sceneView.session.currentFrame?.camera.transform)!, force)
                
                let vectorForce = SCNVector3(x:rotatedForce.x/10, y:rotatedForce.y/100, z:rotatedForce.z/10)
                node.physicsBody?.applyForce(vectorForce, asImpulse: true)
               node.physicsBody?.isAffectedByGravity = true
            }
        }
        if (sender.state == .began) {
            print("began!")
        }
    }
    
    @IBAction func reset(_ sender: Any) {
        restartSession()
    }
    func restartSession() {
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.pause()
        sceneView.scene.rootNode.enumerateChildNodes{(node, _) in
            node.removeFromParentNode()
        }
        sceneView.session.run(configuration, options: [.resetTracking,.removeExistingAnchors])
        showWorldOrigin()
        
    }
    func randomNumber(firstNum: CGFloat, secondNum: CGFloat) -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UINT32_MAX) + abs(firstNum - secondNum) + min(firstNum, secondNum)
    }
    func showWorldOrigin(){
        sceneView.debugOptions = [.showPhysicsShapes, ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
        
    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let anchorPlane = anchor as? ARPlaneAnchor else { return }
        print("New Plane Anchor found at ", anchorPlane.extent)
        let floor = createFloor(anchor: anchorPlane)
        let goal = addGoal(anchor: anchorPlane)
        node.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: SCNBox(width: 0.1, height: 0.25, length: 0.05, chamferRadius: 0), options: nil))
        node.physicsBody?.categoryBitMask = BodyType.box.rawValue
        node.physicsBody?.collisionBitMask = BodyType.ball.rawValue
        node.physicsBody?.contactTestBitMask = BodyType.ball.rawValue
        node.addChildNode(floor)
        node.addChildNode(goal)
    }
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let anchorPlane = anchor as? ARPlaneAnchor else { return }
        print("Plane Anchor updated with extent ", anchorPlane.extent)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let anchorPlane = anchor as? ARPlaneAnchor else { return }
        print("Plane Anchor removed with extent ", anchorPlane.extent)
        removeNode(named: "floor")
    }

    
    func createFloor(anchor: ARPlaneAnchor) -> SCNNode{
        let floor = SCNNode()
        floor.name = "floor"
        floor.eulerAngles = SCNVector3(Double.pi/2,0,0)
        floor.geometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        floor.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        floor.geometry?.firstMaterial?.isDoubleSided = true
        floor.position = SCNVector3(anchor.center.x,anchor.center.y,anchor.center.z)
        //floor.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: nil)
        return floor
    }
    
    func addGoal(anchor: ARPlaneAnchor) -> SCNNode {
        let myNode = ViewController.collada2SCNNode(filepath: "art.scnassets/SoccerGoal.dae")
        myNode.position = SCNVector3(anchor.center.x, anchor.center.y + 0.01, anchor.center.z)
        myNode.scale = SCNVector3(0.025,0.025,0.025)
        //myNode.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: SCNBox(width: 0.1, height: 0.25, length: 0.1, chamferRadius: 0), options: nil))
        return myNode
    }
    
    class func collada2SCNNode(filepath:String) -> SCNNode {
        
        let node = SCNNode()
        let scene = SCNScene(named: filepath)
        let nodeArray = scene!.rootNode.childNodes
        
        for childNode in nodeArray {
            
            if(childNode.name == "Goal"){
                node.addChildNode(childNode as SCNNode)
            }
            if(childNode.name == "Net"){
                print("Net")
                //childNode.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: nil)
                node.addChildNode(childNode as SCNNode)
            }
            
            
        }
        
        return node
        
    }
    
    func removeNode(named: String) {
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if(node.name == named){
                node.removeFromParentNode()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
