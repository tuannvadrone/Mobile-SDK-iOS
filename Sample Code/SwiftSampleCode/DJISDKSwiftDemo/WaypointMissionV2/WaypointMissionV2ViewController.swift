//
//  WaypointMissionV2ViewController.swift
//  DJISDKSwiftDemo
//
//  Created by Tuan Nguyen on 15/09/2022.
//  Copyright © 2022 DJI. All rights reserved.
//

import UIKit
import DJISDK
import CoreLocation

enum WaypointV2Action {
    case STAY
    case START_MOVING
    case TAKE_PHOTO
    case START_RECORD
    case STOP_RECORD
    case ROTATE_HEADING
    case ROTATE_GIMBAL
    case ROTATE_GIMBAL_PAN
    case REACH_POINT
    case START_INTERVAL_SHOOTING
    case STOP_INTERVAL_SHOOTING
    case ZOOM
}

final class WaypointMissionV2ViewController: UIViewController {
    var missionV2Operator: DJIWaypointV2MissionOperator! {
        DJISDKManager.missionControl()!.waypointV2MissionOperator()
    }
    var fController: DJIFlightController? {
        guard let product = DJISDKManager.product() else {
            return nil
        }
        if (product.isKind(of: DJIAircraft.self)) {
            let flightController = (product as! DJIAircraft).flightController
            return flightController
        }
        return nil
    }
    var fCamera: DJICamera? {
        let product = DJISDKManager.product()
        if (product == nil) {
            return nil
        }
        if (product!.isKind(of: DJIAircraft.self)) {
            return (product as! DJIAircraft).camera
        } else if (product!.isKind(of: DJIHandheld.self)) {
            return (product as! DJIHandheld).camera
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func prepareMission(_ sender: Any) {
        settingBeforeFlight { error in
            print("===> setting before flight error: \(error)")
            self.loadMission()
            DJISDKManager.product()?.camera?.delegate = self
        }
    }
    
    @IBAction func flyMission(_ sender: Any) {
        print("===> Mission started")
        missionV2Operator.startMission { error in
            print("===> Mission started error = \(error)")
        }
    }
    
    @IBAction func endMission(_ sender: Any) {
        print("===> abort all was started")
        abortAll { error in
            print("===> abort all done: error = \(error)")
        }
    }
    
    @IBAction func landing(_ sender: Any) {
        print("===> landing started...")
        fController?.startLanding(completion: { error in
            print("==> landing finished: error: \(error)")
        })
    }
    
    func abortAll(_ completion: ((_ error: Error?) -> Void)?) {
        guard let opera = missionV2Operator else {
            return
        }
        opera.stopMission(completion: { error in
            opera.removeAllListeners()
            completion?(error)
        })
    }
    func settingBeforeFlight(_ completion: ((_ error: Error?) -> ())?) {
        var params = [String: Any]()
        //MARK: hard code for can fly
        params["homeLocation"] = CLLocation(latitude: 33.6209929,
                                            longitude: 130.6265251)
//        params["droneLocation"] = CLLocation(latitude: mainStore.state.currentDroneStatus.droneLatitude,
//                                             longitude: mainStore.state.currentDroneStatus.droneLongitude)
        params["goHomeHeight"] = UInt(70)
        params["enableMaxFlightDistance"] = true
        params["maxFlightDistance"] = UInt(1000)
        params["maxFlightHeight"] =  UInt(200)
        
        
        let maxFlightRadiusLimitation = params["maxFlightDistance"] as? UInt ?? UInt(0)
        let enableMaxFlightDistance = params["enableMaxFlightDistance"] as! Bool
        let maxFlightHeight = params["maxFlightHeight"] as? UInt ?? UInt(500)
        let newHomeLocation: CLLocation?
        if let homeLocation = params["homeLocation"] as? CLLocation, (homeLocation.coordinate.latitude != 0.0 && homeLocation.coordinate.longitude != 0.0) {
            newHomeLocation = homeLocation
        } else {
            newHomeLocation = params["droneLocation"] as? CLLocation
        }
        
        guard let control = self.fController, let camera = self.fCamera else { return }
        if let newHomeLocation = newHomeLocation {
            control.setHomeLocation(newHomeLocation, withCompletion: nil)
        }
        if let goHomeHeight = params["goHomeHeight"] as? UInt {
            control.setGoHomeHeightInMeters(goHomeHeight, withCompletion: nil)
        }
        control.setMaxFlightRadiusLimitationEnabled(enableMaxFlightDistance, withCompletion: nil)
        if enableMaxFlightDistance {
            control.setMaxFlightRadius(maxFlightRadiusLimitation, withCompletion: nil)
        }
        camera.setFocusMode(.auto, withCompletion: nil)
        camera.setMode(.shootPhoto, withCompletion: nil)
        camera.setPhotoFileFormat(.JPEG)
        if camera.displayName == DJICameraDisplayNameZenmuseH20T || camera.displayName == DJICameraDisplayNameZenmuseH20 {
            if let lens = camera.lenses.first {
                lens.getPhotoFileFormat { (type, err) in
                    print("===> getPhotoFileFormat = \(type)")
                    if (err == nil && type != DJICameraPhotoFileFormat.JPEG) {
                        if (type != DJICameraPhotoFileFormat.JPEG) {
                            lens.setPhotoFileFormat(.JPEG, withCompletion: nil)
                        }
                    }
                }
            }
            completion?(nil)
            
        } else {
            camera.getPhotoFileFormat(completion: {(type, err) in
                if (err == nil && type != DJICameraPhotoFileFormat.JPEG) {
                    if (type != DJICameraPhotoFileFormat.JPEG) {
                        camera.setPhotoFileFormat(.JPEG, withCompletion: nil)
                    }
                }
                completion?(err)
            })
        }
        
        control.setMaxFlightHeight(maxFlightHeight, withCompletion: nil)
    }
    
    func loadMission() {
        var listWaypointsV2 = [DJIWaypointV2]()
        var listActionsV2 = [DJIWaypointV2Action]()
        var actionIndex = 0
        
        // 1 ---------------
        let firstWP = DJIWaypointV2()
        firstWP.coordinate = CLLocationCoordinate2D(latitude: 33.6209929, longitude: 130.6265251)
        firstWP.heading = 30
        firstWP.altitude = 20
        firstWP.headingMode = .fixed
        firstWP.autoFlightSpeed = Float(3)
        firstWP.isUsingWaypointAutoFlightSpeed = true
        
        listWaypointsV2.append(firstWP)
        // reach point
        let reachPointAction = createWaypointV2Action(action: .REACH_POINT,
                                                      actionIndex: actionIndex,
                                                      waypointIndex: 0)
        actionIndex = reachPointAction.newActionIndex
        listActionsV2.append(reachPointAction.waypointAction)
       
        // interval shooting
//        let intervalShootingAction = createWaypointV2Action(action: .START_INTERVAL_SHOOTING,
//                                                            actionIndex: actionIndex,
//                                                            waypointIndex: 0)
//        actionIndex = intervalShootingAction.newActionIndex
//        listActionsV2.append(intervalShootingAction.waypointAction)
        // stay
//        let makeDroneStayAction = createWaypointV2Action(action: .STAY,
//                                                         actionIndex: actionIndex,
//                                                         stay: 3)
//        actionIndex = makeDroneStayAction.newActionIndex
//        listActionsV2.append(makeDroneStayAction.waypointAction)
        // moving
        let startMovingAction = createWaypointV2Action(action: .START_MOVING,
                                                       actionIndex: actionIndex)
        actionIndex = startMovingAction.newActionIndex
        listActionsV2.append(startMovingAction.waypointAction)
        
        
        
        // 2 ---------------
        let secondWP = DJIWaypointV2()
        secondWP.coordinate = CLLocationCoordinate2D(latitude: 33.6211096, longitude: 130.6265459)
        secondWP.heading = 90
        secondWP.altitude = 60
        secondWP.headingMode = .fixed
        secondWP.autoFlightSpeed = Float(3)
        secondWP.isUsingWaypointAutoFlightSpeed = true
        
        listWaypointsV2.append(secondWP)
        // reach point
        let reachPointAction2 = createWaypointV2Action(action: .REACH_POINT,
                                                       actionIndex: actionIndex,
                                                       waypointIndex: 1)
        actionIndex = reachPointAction2.newActionIndex
        listActionsV2.append(reachPointAction2.waypointAction)
        // stay
//        let makeDroneStayAction2 = createWaypointV2Action(action: .STAY,
//                                                          actionIndex: actionIndex,
//                                                          stay: 3)
//        actionIndex = makeDroneStayAction2.newActionIndex
//        listActionsV2.append(makeDroneStayAction2.waypointAction)
        // moving
        let startMovingAction2 = createWaypointV2Action(action: .START_MOVING,
                                                        actionIndex: actionIndex)
        actionIndex = startMovingAction2.newActionIndex
        listActionsV2.append(startMovingAction2.waypointAction)
        
        
        // 3 ---------------
//        let thirdWP = DJIWaypointV2()
//        thirdWP.coordinate = CLLocationCoordinate2D(latitude: 33.6211166, longitude: 130.6263363)
//        thirdWP.heading = 40
//        thirdWP.altitude = 100
//        thirdWP.headingMode = .fixed
//        thirdWP.autoFlightSpeed = Float(3)
//        thirdWP.isUsingWaypointAutoFlightSpeed = true
//
//        listWaypointsV2.append(thirdWP)
//        // reach point
//        let reachPointAction3 = createWaypointV2Action(action: .REACH_POINT,
//                                                       actionIndex: actionIndex,
//                                                       waypointIndex: 2)
//        actionIndex = reachPointAction3.newActionIndex
//        listActionsV2.append(reachPointAction3.waypointAction)
//        // stay
//        let makeDroneStayAction3 = createWaypointV2Action(action: .STAY,
//                                                          actionIndex: actionIndex,
//                                                          stay: 3)
//        actionIndex = makeDroneStayAction3.newActionIndex
//        listActionsV2.append(makeDroneStayAction3.waypointAction)
//        // moving
//        let startMovingAction3 = createWaypointV2Action(action: .START_MOVING,
//                                                        actionIndex: actionIndex)
//        actionIndex = startMovingAction3.newActionIndex
//        listActionsV2.append(startMovingAction3.waypointAction)
//
//
//
//        // 4 ----------------
//        let fourthWP = DJIWaypointV2()
//        fourthWP.coordinate = CLLocationCoordinate2D(latitude: 33.6210214, longitude: 130.6262254)
//        fourthWP.heading = 60
//        fourthWP.altitude = 12
//        fourthWP.headingMode = .fixed
//        fourthWP.autoFlightSpeed = Float(3)
//        fourthWP.isUsingWaypointAutoFlightSpeed = true
//
//        listWaypointsV2.append(fourthWP)
//        // reach point
//        let reachPointAction4 = createWaypointV2Action(action: .REACH_POINT,
//                                                       actionIndex: actionIndex,
//                                                       waypointIndex: 3)
//        actionIndex = reachPointAction4.newActionIndex
//        listActionsV2.append(reachPointAction4.waypointAction)
//        // stay
//        let makeDroneStayAction4 = createWaypointV2Action(action: .STAY,
//                                                          actionIndex: actionIndex,
//                                                          stay: 3)
//        actionIndex = makeDroneStayAction4.newActionIndex
//        listActionsV2.append(makeDroneStayAction4.waypointAction)
        // moving
//        let startMovingAction4 = createWaypointV2Action(action: .START_MOVING,
//                                                        actionIndex: actionIndex)
//        actionIndex = startMovingAction4.newActionIndex
//        listActionsV2.append(startMovingAction4.waypointAction)
        
        
        let tempMissionV2 = DJIMutableWaypointV2Mission()
        tempMissionV2.maxFlightSpeed = Float(5)
        tempMissionV2.finishedAction = .noAction
        tempMissionV2.gotoFirstWaypointMode = .safely
        tempMissionV2.exitMissionOnRCSignalLost = false
        tempMissionV2.autoFlightSpeed = Float(5)
        tempMissionV2.repeatTimes = 2
        tempMissionV2.addWaypoints(listWaypointsV2)
        
        let missionV2 = DJIWaypointV2Mission(mission: tempMissionV2)
        missionV2Operator.removeAllListeners()
        missionV2Operator.load(missionV2) { error in
            print("===> load mission error: \(error)")
            
            // upload mission
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if self.missionV2Operator.currentState == .readyToUpload {
                    self.missionV2Operator.uploadMission { error in
                        if let error = error {
                            print("===> upload mission failed: error = \(error)")
                        } else {
                            print("===> upload mission succeed")
                        }
                    }
                }
            }
            
            guard error == nil else { return }
            
            self.missionV2Operator.addListener(toActionUploadEvent: self, with: .main) { event in
                if event.currentState == .readyToUpload {
                    // upload actions
                    self.missionV2Operator.uploadWaypointActions(listActionsV2) { error in
                        print("===> upload actions: error = \(error)")
                    }
                } else if event.previousState == .uploading
                            && event.currentState == .readyToExecute {
                    print("===> Mission V2 ready to EXECUTE")
                }
                print("===> action upload: totalActionCount = \(event.progress?.totalActionCount) - lastUploadedActionIndex = \(event.progress?.lastUploadedActionIndex) - debugDescription \(event.progress.debugDescription)")
            }
            
            self.missionV2Operator.addListener(toExecutionEvent: self, with: .main, andBlock: { event in
                if let error = event.error {
                    print("===>> execution action failed: \(error)")
                } else {
                    print("===>> execution action succeed")
                }
                print("===> execution targetWaypointIndex \(event.progress?.targetWaypointIndex) isWaypointReached = \(event.progress?.isWaypointReached)")
            })
            
            self.missionV2Operator.addListener(toFinished: self, with: .main) { error in
                self.missionV2Operator.removeAllListeners()
                if let error = error {
                    print("===>> Mission finished failed: \(error)")
                } else {
                    print("===>> Mission finished succeed")
                }
            }
        }
    }
    
    func createWaypointV2Action(action: WaypointV2Action,
                                actionIndex: Int,
                                waypointIndex: Int = 0,
                                heading: Float = 0.0,
                                gimbal: Int = 0,
                                stay: Double = 0.0,
                                intervalTime: Double = 0.0,
                                zoom: Double = 0.0) -> (newActionIndex: Int, waypointAction: DJIWaypointV2Action) {
        var newActionIndex = actionIndex
        switch action {
        case .REACH_POINT:
            // Reach waypoint: - Trigger Param
            let reachPointTriggerParam = DJIWaypointV2ReachPointTriggerParam()
            reachPointTriggerParam.startIndex = UInt(waypointIndex)
            reachPointTriggerParam.waypointCountToTerminate = UInt(waypointIndex)
            
            let reachPointTrigger = DJIWaypointV2Trigger()
            reachPointTrigger.actionTriggerType = .reachPoint
            reachPointTrigger.reachPointTriggerParam = reachPointTriggerParam
            
            // Reach waypoint: - Actuator Param
            let flyControlParam = DJIWaypointV2AircraftControlFlyingParam()
            flyControlParam.isStartFlying = false
            
            let reachPointActuatorParam = DJIWaypointV2AircraftControlParam()
            reachPointActuatorParam.operationType = .flyingControl
            reachPointActuatorParam.flyControlParam = flyControlParam
            
            let reachPointActuator = DJIWaypointV2Actuator()
            reachPointActuator.type = .aircraftControl
            reachPointActuator.aircraftControlActuatorParam = reachPointActuatorParam
            
            // Reach waypoint: - Combine Trigger & Actuator
            if newActionIndex != 0 {
                newActionIndex += 1
            }
            let reachPointAction = DJIWaypointV2Action()
            reachPointAction.actionId = UInt(newActionIndex)
            reachPointAction.trigger = reachPointTrigger
            reachPointAction.actuator = reachPointActuator
            
            return (newActionIndex, reachPointAction)
        case .ROTATE_GIMBAL:
            // GIMBAL_TILT - trigger
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(3)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // GIMBAL_TILT - actuator
            let actuatorParam = DJIWaypointV2GimbalActuatorParam()
            actuatorParam.operationType = .rotateGimbal
            if abs(gimbal) == 90 {
                actuatorParam.rotation = DJIGimbalRotation(pitchValue: -90,
                                                           rollValue: 0,
                                                           yawValue: nil,
                                                           time: 3.0,
                                                           mode: .absoluteAngle,
                                                           ignore: true)
            } else {
                actuatorParam.rotation = DJIGimbalRotation(pitchValue: NSNumber(value: gimbal),
                                                           rollValue: 0,
                                                           yawValue: nil,
                                                           time: 3.0,
                                                           mode: .absoluteAngle,
                                                           ignore: true)
            }
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .gimbal
            actuator.gimbalActuatorParam = actuatorParam
            
            // GIMBAL_TILT - combine
            newActionIndex += 1
            
            let rotateGimbalAction = DJIWaypointV2Action()
            rotateGimbalAction.actionId = UInt(newActionIndex)
            rotateGimbalAction.trigger = trigger
            rotateGimbalAction.actuator = actuator
            
            return (newActionIndex, rotateGimbalAction)
        case .ROTATE_GIMBAL_PAN:
            // GIMBAL_PAN - trigger
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(3)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // GIMBAL_PAN - actuator
            let actuatorParam = DJIWaypointV2GimbalActuatorParam()
            actuatorParam.operationType = .rotateGimbal
            actuatorParam.rotation = DJIGimbalRotation(pitchValue: nil,
                                                       rollValue: 0,
                                                       yawValue: NSNumber(value: gimbal),
                                                       time: 3.0,
                                                       mode: .absoluteAngle,
                                                       ignore: true)
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .gimbal
            actuator.gimbalActuatorParam = actuatorParam
            
            // GIMBAL_TILT - combine
            newActionIndex += 1
            
            let rotateGimbalAction = DJIWaypointV2Action()
            rotateGimbalAction.actionId = UInt(newActionIndex)
            rotateGimbalAction.trigger = trigger
            rotateGimbalAction.actuator = actuator
            
            return (newActionIndex, rotateGimbalAction)
        case .ROTATE_HEADING:
            // HEADING - Trigger:
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(5)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // HEADING - Actuator:
            let rotateDroneHeadingActuatorParam = DJIWaypointV2AircraftControlRotateHeadingParam()
            rotateDroneHeadingActuatorParam.isRelative = false
            rotateDroneHeadingActuatorParam.direction = .clockwise
            rotateDroneHeadingActuatorParam.heading = heading
            
            let aircraftControlActuatorParam = DJIWaypointV2AircraftControlParam()
            aircraftControlActuatorParam.operationType = .rotateYaw
            aircraftControlActuatorParam.yawRotatingParam = rotateDroneHeadingActuatorParam
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .aircraftControl
            actuator.aircraftControlActuatorParam = aircraftControlActuatorParam
            
            // HEADING - Combine:
            newActionIndex += 1
            
            let rotateHeadingAction = DJIWaypointV2Action()
            rotateHeadingAction.actionId = UInt(newActionIndex)
            rotateHeadingAction.trigger = trigger
            rotateHeadingAction.actuator = actuator
            
            return (newActionIndex, rotateHeadingAction)
        case .START_RECORD:
            // START_RECORD - trigger:
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(3)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // START_RECORD - actuator:
            let actuatorParam = DJIWaypointV2CameraActuatorParam()
            actuatorParam.operationType = .startRecordVideo
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .camera
            actuator.cameraActuatorParam = actuatorParam
            
            // START_RECORD - combine:
            newActionIndex += 1
            
            let startRecordAction = DJIWaypointV2Action()
            startRecordAction.actionId = UInt(newActionIndex)
            startRecordAction.trigger = trigger
            startRecordAction.actuator = actuator
            
            return (newActionIndex, startRecordAction)
        case .STOP_RECORD:
            // STOP_RECORD - trigger:
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(3)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // STOP_RECORD - actuator:
            let actuatorParam = DJIWaypointV2CameraActuatorParam()
            actuatorParam.operationType = .stopRecordVideo
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .camera
            actuator.cameraActuatorParam = actuatorParam
            
            // STOP_RECORD - combine:
            newActionIndex += 1
            
            let stopRecordAction = DJIWaypointV2Action()
            stopRecordAction.actionId = UInt(newActionIndex)
            stopRecordAction.trigger = trigger
            stopRecordAction.actuator = actuator
            
            return (newActionIndex, stopRecordAction)
        case .STAY:
            // HOVERING - Trigger: Make drone stop moving
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(stay)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // HOVERING - Actuator: Make drone stop moving
            let flyControlParam = DJIWaypointV2AircraftControlFlyingParam()
            flyControlParam.isStartFlying = false
            
            let actuatorParam = DJIWaypointV2AircraftControlParam()
            actuatorParam.operationType = .flyingControl
            actuatorParam.flyControlParam = flyControlParam
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .aircraftControl
            actuator.aircraftControlActuatorParam = actuatorParam
            
            // HOVERING - Combine Trigger & Actuator: Make drone stop moving
            newActionIndex += 1
            
            let stayAction = DJIWaypointV2Action()
            stayAction.actionId = UInt(newActionIndex)
            stayAction.trigger = trigger
            stayAction.actuator = actuator
            
            return (newActionIndex, stayAction)
        case .START_MOVING:
            // START_MOVING - Trigger:
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(5)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // START_MOVING - Actuator:
            let flyControlParam = DJIWaypointV2AircraftControlFlyingParam()
            flyControlParam.isStartFlying = true
            
            let actuatorParam = DJIWaypointV2AircraftControlParam()
            actuatorParam.operationType = .flyingControl
            actuatorParam.flyControlParam = flyControlParam
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .aircraftControl
            actuator.aircraftControlActuatorParam = actuatorParam
            
            // START_MOVING - Combine Trigger & Actuator: Make drone start moving
            newActionIndex += 1
            
            let startMovingAction = DJIWaypointV2Action()
            startMovingAction.actionId = UInt(newActionIndex)
            startMovingAction.trigger = trigger
            startMovingAction.actuator = actuator
            
            return (newActionIndex, startMovingAction)
        case .TAKE_PHOTO:
            // IMAGE_SHOOTING - trigger:
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(3)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // IMAGE_SHOOTING - actuator:
            let actuatorParam = DJIWaypointV2CameraActuatorParam()
            actuatorParam.operationType = .takePhoto
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .camera
            actuator.cameraActuatorParam = actuatorParam
            
            // IMAGE_SHOOTING - combine:
            newActionIndex += 1
            
            let takePhotoAction = DJIWaypointV2Action()
            takePhotoAction.actionId = UInt(newActionIndex)
            takePhotoAction.trigger = trigger
            takePhotoAction.actuator = actuator
            
            return (newActionIndex, takePhotoAction)
        case .START_INTERVAL_SHOOTING:
            // START_INTERVAL - trigger:
            let triggerParam = DJIWaypointV2IntervalTriggerParam()
            triggerParam.actionIntervalType = .time
            triggerParam.interval = Float(intervalTime)
            triggerParam.startIndex = UInt(waypointIndex)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .interval
            trigger.intervalTriggerParam = triggerParam
            
            // START_INTERVAL - actuator:
            let actuatorParam = DJIWaypointV2CameraActuatorParam()
            actuatorParam.operationType = .takePhoto
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .camera
            actuator.cameraActuatorParam = actuatorParam
            
            // START_INTERVAL - combine:
            newActionIndex += 1
            
            let intervalShootingAction = DJIWaypointV2Action()
            intervalShootingAction.actionId = UInt(newActionIndex)
            intervalShootingAction.trigger = trigger
            intervalShootingAction.actuator = actuator
            
            return (newActionIndex, intervalShootingAction)
        case .STOP_INTERVAL_SHOOTING:
            break
        case .ZOOM:
            let triggerParam = DJIWaypointV2AssociateTriggerParam()
            triggerParam.actionIdAssociated = UInt(newActionIndex)
            triggerParam.actionAssociatedType = .afterFinished
            triggerParam.waitingTime = UInt(3)
            
            let trigger = DJIWaypointV2Trigger()
            trigger.actionTriggerType = .actionAssociated
            trigger.associateTriggerParam = triggerParam
            
            // ZOOM - actuator:
            let zoomParam = DJIWaypointV2CameraFocalLengthParam()
            zoomParam.focalLength = UInt(zoom)
            let actuatorParam = DJIWaypointV2CameraActuatorParam()
            actuatorParam.operationType = .zoom
            actuatorParam.zoomParam = zoomParam
            
            let actuator = DJIWaypointV2Actuator()
            actuator.type = .camera
            actuator.cameraActuatorParam = actuatorParam
            
            // START_INTERVAL - combine:
            newActionIndex += 1
            
            let intervalShootingAction = DJIWaypointV2Action()
            intervalShootingAction.actionId = UInt(newActionIndex)
            intervalShootingAction.trigger = trigger
            intervalShootingAction.actuator = actuator
            
            return (newActionIndex, intervalShootingAction)
        }
        return (-1, DJIWaypointV2Action())
    }
}

extension WaypointMissionV2ViewController: DJICameraDelegate {
    func camera(_ camera: DJICamera, didGenerateNewMediaFile newMedia: DJIMediaFile) {
        print("New 🌇: \(newMedia.fileName)")
    }
}
