//
//  ViewController.swift
//  ARFloor
//
//  Created by Yacha Toueg on 10/24/18.
//  Copyright © 2018 Yacha Toueg. All rights reserved.
// REPLACING HORIZONTAL SURFACE WITH TEXTURES!

import UIKit
import ARKit
import CoreMotion

class ViewController: UIViewController, ARSCNViewDelegate  {
   
    @IBOutlet weak var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    let motionManager = CMMotionManager()
    var vehicle = SCNPhysicsVehicle()
    var orientation: CGFloat = 0
    var accelerationValues = [UIAccelerationValue(0),UIAccelerationValue(0)]
    // the first accelertionValue represents the x direction while the second acceleration value represents the y direction.
    var touched: Bool = false
    override func viewDidLoad() {
        super.viewDidLoad()
        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        self.configuration.planeDetection = .horizontal
        self.sceneView.session.run(configuration)
        self.sceneView.delegate = self
        self.setUpAccelerometer()
        self.sceneView.showsStatistics = true
        // Do any additional setup after loading the view, typically from a nib.
        
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //DRIVING THE CAR - IDEA IS THAT WHEN THE SCREEN IS TOUCHED, THE CAR SHOULD DRIVE

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touched = true
            }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touched = false

    }
    func createRoad(planeAnchor: ARPlaneAnchor) -> SCNNode {
        //we need to adjust the size of the "road" node according to the size of the plane
        let roadNode = SCNNode(geometry: SCNPlane(width:CGFloat(planeAnchor.extent.x), height:CGFloat(planeAnchor.extent.z)))
        roadNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named:"lightroad")
        //position the road node 1m behind Z axis
        roadNode.position = SCNVector3(planeAnchor.center.x,planeAnchor.center.y,planeAnchor.center.z)
        //we must rotate the roadNode horizontally
        roadNode.eulerAngles = SCNVector3(90.degreesToRadians,0,0)
        roadNode.geometry?.firstMaterial?.isDoubleSided = true //this makes sure that the road image will cover both sides of the image
        // we need to add physics to the road node in order for the car to be dropped and be on the road.
        
        let staticBody = SCNPhysicsBody.static()
        roadNode.physicsBody=staticBody
        
        // Static is designed for fixtures. Anything that is going to be fixed in one place but needs to support other bodies.
        //In our case, we need the road to support the box. The road node will remain in its fixed position but will be able to collide with any physical body that hits it.
        return roadNode
    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {return}
        let roadNode = createRoad(planeAnchor: planeAnchor)
        node.addChildNode(roadNode)
        print("new flat surface detected, new ARPlaneAnchor added")
        
    }
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {return}
        print("updating floor's anchor...")
        //in order to have the water node be updated as we move the phone along plane surfaces
        node.enumerateChildNodes {(childNode,_)in
            childNode.removeFromParentNode()
        }
        // we need to update the road dimension with the updated plane Anchor

        let roadNode = createRoad(planeAnchor: planeAnchor)
        node.addChildNode(roadNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        node.enumerateChildNodes {(childNode,_)in
            childNode.removeFromParentNode()
        }
    }
    
    @IBAction func addCar(_ sender: Any) {
        //we will need to place the box in the current position of the camera
        // let's add the point of view of the sceneview with guardlet
        guard let pointOfView = sceneView.pointOfView else {return}
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31,-transform.m32,-transform.m33)
        let location = SCNVector3(transform.m41,transform.m42, transform.m43)
        let currentPositionOfCamera = orientation + location
        
        
        let scene = SCNScene(named:"Car-Scene.scn")
        let chassis = (scene?.rootNode.childNode(withName: "chassis", recursively: false))!
        let frontLeftWheel = chassis.childNode(withName:"frontLeftParent", recursively:false)!
        let frontRightWheel = chassis.childNode(withName:"frontRightParent", recursively:false)!
        let rearRightWheel = chassis.childNode(withName:"rearRightParent", recursively:false)!
        let rearLeftWheel = chassis.childNode(withName:"rearLeftParent", recursively:false)!
        
        let v_frontLeftWheel = SCNPhysicsVehicleWheel(node: frontLeftWheel)
        let v_frontRightWheel = SCNPhysicsVehicleWheel(node: frontRightWheel)
        let v_rearLeftWheel = SCNPhysicsVehicleWheel(node: rearLeftWheel)
        let v_rearRightWheel = SCNPhysicsVehicleWheel(node: rearRightWheel)

        //we can now put all the wheels into the wheels array!


 
//        let box = SCNNode(geometry: SCNBox(width:0.1, height:0.1, length:0.1,chamferRadius:0))
//        box.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        chassis.position = currentPositionOfCamera
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: chassis, options: [SCNPhysicsShape.Option.keepAsCompound:true]))
        chassis.physicsBody = body
        body.mass = 1
        // the mass of the car controls the speed when the user taps on the screen
        //by putting dynamic, we say that we want the box to be affected by forces
        //add the box to the sceneView
        self.vehicle = SCNPhysicsVehicle(chassisBody: chassis.physicsBody!, wheels: [v_rearRightWheel,v_rearLeftWheel,v_frontRightWheel,v_frontLeftWheel])
        self.sceneView.scene.physicsWorld.addBehavior(self.vehicle)
        //physicsWorld is a property used to manage how certain phyics bodies participate in physics simulations.
        self.sceneView.scene.rootNode.addChildNode(chassis)
        
        // we created the variable vehicle so that the car that we have in our scene file can ACT like a car
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
     //   print("simulating physics")
        var engineForce: CGFloat = 0
        self.vehicle.setSteeringAngle(-orientation, forWheelAt: 2)
        self.vehicle.setSteeringAngle(-orientation, forWheelAt: 3)
        if self.touched == true {
            engineForce = 6
        } else {
            engineForce = 0
        }
        self.vehicle.applyEngineForce(engineForce, forWheelAt: 0)
        self.vehicle.applyEngineForce(engineForce, forWheelAt: 1)

    }
    
    //accelerometer function for phone's orientation
    func setUpAccelerometer(){
        if motionManager.isAccelerometerAvailable{
            motionManager.accelerometerUpdateInterval = 1/60
            motionManager.startAccelerometerUpdates(to: .main, withHandler:{(accelerometerData,error)in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
              self.accelerometerDidChange(acceleration: accelerometerData!.acceleration)
            })
        }
        else {
            print("no accelerometer")
            
        }
    }
    func accelerometerDidChange(acceleration: CMAcceleration){
       // print(acceleration.x)
        accelerationValues[1] = filtered(previousAcceleration: accelerationValues[1], UpdatedAcceleration: acceleration.y)
        print(acceleration.y)
        self.orientation = CGFloat(acceleration.y)
            // now that we have the orientation of the phone, we can orient the wheels accordingly
        // we set the steering angle equal to the orientation of the phone which is just equal to the vertical gravitational acceleration
        // when the phone is completely horizontal, the gravitional acceleration is going to be zero or appproach. when the steering angle is 0, the wheel won't rotate at all since there will be no angle of rotation. As you move your phone to the right, the steering angle gets close to negative one, making the wheels move to the right
        
        accelerationValues[0] = filtered(previousAcceleration: accelerationValues[0], UpdatedAcceleration: acceleration.x)
        if accelerationValues[0] > 0 {
            self.orientation = -CGFloat(accelerationValues[1])
        } else {
            self.orientation = CGFloat(accelerationValues[1])
        }
        // this if statement is important: we are using the vertical acceleration y to set our orientation. The vertical acceleration is reversed when the phone is rotated horizontally such that the camera position where the user's right hand is. Where the phone is in that position such that the camera is where the user's right hand is, the acceleration is always positive and the y acceleration is reversed; So if the x acceleration is positive then unreverse the  Y acceleration and the steering angle is fixed. Otherwise, if the acceleration.x is not bigger than 0 (if camera is positioned in the left hand) leave as is
    }
    func filtered(previousAcceleration: Double, UpdatedAcceleration: Double) -> Double {
        let kfilteringFactor = 0.5
        return UpdatedAcceleration * kfilteringFactor + previousAcceleration * (1-kfilteringFactor)
    }
    // this function filters out any acceleration that is not gravitational. More explanation here: Let's say that when the user runs the app and the phone is vertical and this = 1. User the reorients his phone and the accelerometer updates us on the new acceleration du to gravity acceleration, which could be something like 0.9. However, we need to filter out the 0.9 value from any accelerations that are not gravitational and we do that by putting our previous acceleration value which was "accelerationValues[1]", our updatedacceleration value which is 0.9; we would put both of these accelerations into our function and through a complex equation it would return a filtered acceleration due to gravity that better reflects the orientation of the phone. 
}

func +(left: SCNVector3, right: SCNVector3) -> SCNVector3{
    return SCNVector3Make(left.x + right.x, left.y + right.y , left.z + right.z)
}
extension Int {
    var degreesToRadians: Double {return Double(self) * .pi/180}
}

//NOTES ON ACCELEROMETER
//the closer your phone is being vertical, the higher your vertical acceleration. The closer it is to the horizontal, the higher your horizontal acceleration.
//print(acceleration.x) // acceleration.x is  going to equal how much gravity is being applied in the horizontal face of the phone. if acceleration.x=1, that means all the gravity is being applied in the x direction. if it is = 0, that means no gravitational force is being applied in the X direction of the horizontal direction acceleration.
//print(acceleration.y) // acceleration.y is going to equal how much gravity is being applied in the vertical direction.

