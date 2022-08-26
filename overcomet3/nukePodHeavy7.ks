@lazyglobal off.

// Worked well with OverComet_SH3_test2

set ship:loaddistance:orbit:load to 10001.
set ship:loaddistance:orbit:unpack to 10000.

local COMET_HOVER_DISTANCE to 40.
local MINER_HOVER_DISTANCE to 40.
local COLLISION_AVOIDANCE_LOAD_THRESHOLD to 90.
local DOCKING_PORT_HOVER_DISTANCE to 13.
local SURFACE_ANGLE_TOLERANCE to 25.
local NUMBER_OF_PODS to 8.
local SHOW_DIAG_ARROWS to false.

local cometName to findCometName().

if (core:tag = "RCEnginePod1") {
  core:part:getModule("kOSProcessor"):doEvent("Open Terminal").
}

local endProgram to false.
local shipModeReference to doWait@.
local attachedOrDocked to true.
local podNumber to 0.
local spherePositionVector to 0.

local pointingDir to 0.
local engineDir to heading(0, 0):forevector.
local throttleValue to 0.
local engineThrottle to 0.
local engineSmoothedThrottle to 0.

local diagArrow1 to 0.
local diagArrow2 to 0.
local diagArrow3 to 0.

local centralServo to 0.
local centralServoModule to 0.
local centralServoLocked to 0.
local lastCentralServoAngle to 0.
local leftServo to 0.
local leftServoModule to 0.
local leftServoLocked to 0.
local lastleftServoAngle to 0.
local nukeEngines to list().
local nukeEngine1 to 0.
local nukeEngine2 to 0.
local nukeEngine3 to 0.
local nukeEngine4 to 0.
local dockingPort to 0.
local targetDockingPort to 0.
local controlPod to 0.
local talonClaw to 0.
local talonClawGrappleNode to 0.
local talonClawModuleAnimateGeneric to 0.
local laserRangeFinder to 0.
local laserRangeFinderModule to 0.

// Cached values for performance
local lastHorizontalServoAngle to -900.
local lastVerticalServoAngle to -900.
local cachedCraftAvoidance to V(0,0,0).

local messageQueue to 0.
local corQueue to 0.
local lastMessage to "NONE".
local diagMessage to "".

local cometTarget to 0.
local cometRadius to 0.
local cometHoverDistance to 0.
local minerShip to 0.
local minerShipSet to false.
local minerName to 0.
local clearedForDocking to false.
local trackingVessels to list().
local closeTrackingVessels to list().

local LASER_ANGLE_RANGE to 4.
local lastLaserSample to 0.
local laserSampleCurrentIdx to 0.
local laserRangeSamples to lexicon().
for i in range(9) {
  laserRangeSamples:add(i, 100000).
}
local laserHighPointDirection to V(0,0,0).
local angleOfSurface to 0.

// Laser pointer laser angles for sampling
local laserAngles to setupLaserMap(LASER_ANGLE_RANGE).

local headingAngle to 0.
local headingUpAngle to 0.

set SteeringManager:ROLLCONTROLANGLERANGE to 180.

findDroneParts().

// set diagArrow2 TO vecdraw(V(0,0,0), ship:controlpart:facing:topvector * 10, RGB(1,0,0), "top", 1.0, TRUE, 0.2, TRUE, TRUE).

until endProgram = true {

  shipModeReference().

  if (terminal:input:haschar) {
    handleInput().
  }

  printControlData().

  if (attachedOrDocked) {
    set corQueue TO core:messages.
    if (not corQueue:empty) {
      handleMessage(corQueue:pop():content).
    }
  } else {
    set messageQueue TO ship:messages.
    if (not messageQueue:empty) {
      handleMessage(messageQueue:pop():content).
    }
  }
}

doCleanup().

function doWait {
  // Doing nothing.
  wait 0.
}

function doPointControl {
  if (angularVel:mag > .05) {
    local torqueVec to vcrs(controlPod:position, angularMomentumInShipRaw()).

    if (vang(torqueVec, engineDir) > 140) {
      set engineThrottle to 50.
      if (SHOW_DIAG_ARROWS) {
        set diagArrow1 to vecdraw(controlPod:position, controlPod:position * 20, RGB(1,1,0), "Fading", 1.0, TRUE, 0.2, TRUE, TRUE).
      }
    } else {
      hideArrows().
      set engineThrottle to 100.
    }
  } else {
    set engineThrottle to 100.
  }

  doEngineDirectionControl().
  doEngineControl(20).

  wait 0.1.
}

function doSpinControl {
  set engineThrottle to 100.

  // Calculates the torque direction for the engine
  set engineDir to vcrs(controlPod:position, angularMomentumInShipRaw()).

  doEngineDirectionControl().
  doEngineControl(30).

  wait 0.1.
}

function doCreateSpinControl {
  set engineThrottle to 100.
  set engineDir to -vcrs(controlPod:position, angularMomentumInShipRaw()).

  doEngineDirectionControl().
  doEngineControl(10).

  wait 0.
}

function doLaunchControl {
  local cometPosition to cometTarget:position.

  set pointingDir to "kill".
  set engineDir to cometPosition:normalized + -minerShip:position:normalized.
  set engineThrottle to 100.

  doEngineDirectionControl().
  doEngineControl(10).

  wait 3.

  set shipModeReference to doApproachControl@.
  set spherePositionVector to getCubeSphere(podNumber) * cometHoverDistance.

  wait 0.
}

function doApproachControl {

  local vectorToComet to cometTarget:position.
  local distanceToComet to vectorToComet:mag.
  local approachPosition to vectorToComet + spherePositionVector.
  local distanceToApproachPosition to approachPosition:mag.
  local pointingDiff to vang(ship:facing:forevector, vectorToComet).

  // set diagArrow1 TO vecdraw(V(0,0,0), approachPosition, RGB(0,1,0), "ApproachPosition", 1.0, TRUE, 0.2, TRUE, TRUE).

  set diagMessage to "pointingDiff: " + pointingDiff + "       distanceToApproachPosition: " + distanceToApproachPosition.
  if (pointingDiff < 2 and distanceToApproachPosition < 2) {
    unlock steering.
    set engineThrottle to 0.
    doEngineControl(0).
    wait .5.
  }

  local relativeCometVelocity to cometTarget:velocity:orbit - ship:velocity:orbit.
  local desiredTargetApproachVelocity to min(20, distanceToApproachPosition / 10).

  local cometHoverFactor to V(0,0,0).
  if (distanceToComet < cometHoverDistance) {
    set cometHoverFactor to -vectorToComet:normalized * 40.
  }

  local angleRangeCoveredByComet to arctan(cometRadius / sqrt(cometRadius * cometRadius + distanceToComet * distanceToComet)).
  if (vang(approachPosition, vectorToComet) < angleRangeCoveredByComet and distanceToComet < distanceToApproachPosition) {
    set approachPosition to (vxcl(vectorToComet, approachPosition)):normalized * desiredTargetApproachVelocity.
  }

  local otherCraftAvoidance to V(0,0,0).
  local vslDistance to 0.
  local vslPosition to 0.
  local avoidanceForce to 0.
  for vsl in trackingVessels {
    set vslPosition to vsl:position.
    set vslDistance to max(10, vslPosition:mag - 40).
    set avoidanceForce to vslDistance / ((vslDistance / 10) * (vslDistance / 10) * (vslDistance / 10)).
    set otherCraftAvoidance to otherCraftAvoidance + vslPosition:normalized * avoidanceForce.
  }

  local directionToTravel to approachPosition:normalized * desiredTargetApproachVelocity
   + cometHoverFactor
   + relativeCometVelocity
   + (otherCraftAvoidance * -5).

  set pointingDir to vectorToComet.
  if (pointingDiff > 5) {
    lock steering to pointingDir.
  }
  set engineDir to directionToTravel.
  set engineThrottle to directionToTravel:mag * 30.

  if (engineThrottle > 1) {
    doEngineDirectionControl().
  }
  doEngineControl(30).

  wait 0.
}

function doGrabControl {
  if (talonClawGrappleNode:hasevent("release")) {
    set ship:name to "CometEgg".
    set shipModeReference to doWait@.
    set throttleValue to 0.
    unlock steering.
    unlock throttle.
    FUELCELLS OFF.
    set engineDir to V(0,1,0).
    set attachedOrDocked to true.
    doEngineControl(0).
    doEngineDirectionControl().
    laserRangeFinderModule:setField("enabled", false).
    setServosToFlyMode().
  } else {
    if ((cometTarget <> 0 and cometTarget:isdead) or cometTarget = 0) {
      findCometTarget().
    }

    takeLaserSample().

    local vectorToComet to cometTarget:position.
    local relativeCometVelocity to cometTarget:velocity:orbit - ship:velocity:orbit.
    set pointingDir to lookdirup(vectorToComet, ship:facing:upvector).

    local upHillFactor to V(0,0,0).
    local desiredApproachVelocity to 6.
    local distanceToSurface to laserRangeSamples[8].
    if (distanceToSurface < 65) {
      set desiredApproachVelocity to 1.5.
      if (angleOfSurface > SURFACE_ANGLE_TOLERANCE) {
        if (distanceToSurface < 40) {
          set vectorToComet to -vectorToComet.
        } else if (distanceToSurface < 35) {
          set vectorToComet to V(0,0,0).
        }
      }
    }

    if (distanceToSurface < 100 and angleOfSurface > SURFACE_ANGLE_TOLERANCE) {
      set upHillFactor to laserHighPointDirection:normalized.
    }

    local deviationFromCenter to vang(ship:facing:forevector, vectorToComet).
    if (deviationFromCenter > 4) {
      lock steering to pointingDir.
    }

    local directionToTravel to vectorToComet:normalized * desiredApproachVelocity + relativeCometVelocity + upHillFactor.

    set engineDir to directionToTravel.
    set engineThrottle to directionToTravel:mag * 30.

    if (engineThrottle > 1) {
      doEngineDirectionControl().
    }
    doEngineControl(35).
  }

  wait 0.
}

function takeLaserSample {
  local laserSample to laserRangeFinderModule:getField("distance").

  if (laserSample = lastLaserSample) {
    return.
  }

  set lastLaserSample to laserSample.
  set laserRangeSamples[laserSampleCurrentIdx] to laserSample.

  set laserSampleCurrentIdx to laserSampleCurrentIdx + 1.
  if (laserSampleCurrentIdx >= laserRangeSamples:length) {
    set laserSampleCurrentIdx to 0.
    local closestSampleIdx to findClosestLaserPoint().
    set angleOfSurface to findAngleOfSurface(findClosestLaserPoint(), LASER_ANGLE_RANGE).
    set laserHighPointDirection to findRollDirectionOfLaserSample(closestSampleIdx, LASER_ANGLE_RANGE, laserRangeFinder).
  }

  laserRangeFinderModule:setField("bend x", laserAngles[laserSampleCurrentIdx]:x).
  laserRangeFinderModule:setField("bend y", laserAngles[laserSampleCurrentIdx]:y).
}

function doDockingControl {
  local shipFacingForevector to ship:facing:forevector.
  local targetDockingPortPortFacing to targetDockingPort:portfacing.
  local targetDockingPortForeVector to targetDockingPortPortFacing:forevector.
  local targetDockingPortPosition to targetDockingPort:position.

  set pointingDir to lookdirup(targetDockingPortForeVector, targetDockingPortPortFacing:upvector).

  local targetPointInSpace to targetDockingPortForeVector * 12.5 + targetDockingPortPosition.
  local vectorToTarget to targetPointInSpace.

  local distanceToTarget to vectorToTarget:mag.
  local desiredTargetApproachVelocity to distanceToTarget / 6.

  local relativeShipVelocity to minerShip:velocity:orbit - ship:velocity:orbit.

  local dockingVectorToTarget to targetDockingPortPosition.
  local vangToTarget to vang(dockingVectorToTarget, shipFacingForevector).
  local vangShipPositionToTargetDockFacing to vang(targetDockingPortForeVector, targetDockingPortPosition).

  declare local distanceToPort to (dockingPort:position - targetDockingPortPosition):mag.

  local sideWaysVelocity to vxcl(shipFacingForevector, relativeShipVelocity).

  declare local sideWaysCorrectionVector to V(0,0,0).
  // If everything is dialed in, being approach
  if (vangToTarget > 178 and vangShipPositionToTargetDockFacing > 178) {
    set targetPointInSpace to targetDockingPortPosition - (targetDockingPortPosition:normalized * .1).
    set vectorToTarget to targetPointInSpace.

    set desiredTargetApproachVelocity to 0.5.
  } else {
    // Really reinforce steering direction if needed
    lock steering to pointingDir.
  }

  set sideWaysCorrectionVector to vxcl(shipFacingForevector, targetPointInSpace):normalized * .5.

  set engineDir to vectorToTarget:normalized * desiredTargetApproachVelocity + sideWaysCorrectionVector * 0.05 + relativeShipVelocity.
  set engineThrottle to engineDir:mag * 15.

  if (distanceToPort > 0.5) {
    doEngineDirectionControl().
  }
  doEngineControl(8).

  // -------------------------Diag block for docking information
  // clearscreen.
  // print "VectorToTarget:                " + vectorToTarget.
  // print "desiredTargetApproachVelocity: " + desiredTargetApproachVelocity.
  // print "sideWaysVelocityMag:           " + sideWaysVelocity:mag.
  // print "sideWaysCorrectionVector:      " + sideWaysCorrectionVector.
  // print "relativeShipVelocity:          " + relativeShipVelocity.
  // print "EngineDir:                     " + engineDir.
  // print "vangToTarget:                  " + vangToTarget.
  // print "vangShipPositionToTargetDock:  " + vangShipPositionToTargetDockFacing.
  // print "distanceToPort:                " + distanceToPort.
  // print "Throttle:                      " + engineThrottle.

  if (dockingPort:state:contains("Docked")) {
    set attachedOrDocked to true.
    set engineDir to ship:facing:forevector.
    doEngineDirectionControl().
    set shipModeReference to doWait@.
    unlock steering.
    FUELCELLS OFF.
    unlock throttle.
    set engineThrottle to 0.
    doEngineControl(0).
  }

  wait 0.
}

function doCometEvacControl {
  local vectorToCenter to controlPod:position.
  set minerShipSet to false.
  set engineDir to vectorToCenter.
  set engineThrottle to 100.
  set engineSmoothedThrottle to 100.
  doEngineDirectionControl().
  wait 2.
  talonClawGrappleNode:doEvent("release").
  wait 0.
  talonClawModuleAnimateGeneric:doevent("disarm").
  set attachedOrDocked to false.
  fuelcells on.
  set ship:loaddistance:orbit:load to 10001.
  set ship:loaddistance:orbit:unpack to 10000.
  controlPod:controlFrom().
  doEngineControl(30).
  set pointingDir to -vectorToCenter.
  lock steering to pointingDir.
  set throttleValue to 1.
  lock throttle to throttleValue.
  wait 5.
  set shipModeReference to doCometVelocityStabilization@.
  set ship:name to core:tag.
  findNearbyVessels().
}

function doRegroupControl {

  // clearscreen.

  local minerHoverFactor to V(0, 0, 0).
  local minerHoverApproachVelocity to 1.
  local minerAvoidanceFactor to V(0, 0, 0).
  local relativeShipVelocity to V(0, 0, 0).
  local vectorToComet to V(0, 0, 0).
  local distanceToTarget to 0.
  local desiredTargetApproachVelocity to 0.

  local inSafeZone to false.

  if (minerShipSet and not minerShip:isDead) {
    // print "Minership: " + minerShip.

    local targetDockPosition to targetDockingPort:position.
    local targetDockPortFacing to targetDockingPort:portfacing.
    local targetDockPortFacingForevector to targetDockPortFacing:forevector.
    local targetPointInSpace to targetDockPortFacing:forevector * DOCKING_PORT_HOVER_DISTANCE + targetDockPosition.
    set distanceToTarget to targetPointInSpace:mag.

    set desiredTargetApproachVelocity to min(13, distanceToTarget / 9).

    set pointingDir to lookdirup(targetDockPortFacingForevector, targetDockPortFacing:upvector).

    set relativeShipVelocity to minerShip:velocity:orbit - ship:velocity:orbit.

    set minerHoverFactor to targetPointInSpace:normalized * desiredTargetApproachVelocity.

    // If the ship is in a range zone near it's docking port then it should allow for better approach to the
    // docking port without worrying baout collisions with other ships or the miner
    local vangToTarget to vang(targetDockPosition, ship:facing:forevector).
    local vangShipPositionToTargetDockFacing to vang(targetDockPortFacingForevector, targetDockPosition).
    if (vangToTarget < 160 or vangShipPositionToTargetDockFacing < 160) {
      local minerShipPosition to minerShip:position.
      local minerDistance to max(10, minerShipPosition:mag - 44).  // TODO:  change distance val based on final ship.
      set minerAvoidanceFactor to minerShipPosition:normalized * (minerDistance / ((minerDistance / 10) * (minerDistance / 10) * (minerDistance / 10))).

      if (minerShipPosition:mag < 120) {
        set minerHoverFactor to vxcl(minerShipPosition, minerHoverFactor):normalized * desiredTargetApproachVelocity.
      }
    } else {
      set inSafeZone to true.
    }

    // clearscreen.
    // print "DistanceToTargetPointInSpace: " + targetPointInSpace:mag.
    // print "distanceToTarget:             " + distanceToTarget.
    // print "relVelMag:                    " + relativeShipVelocity:mag.

    // If well positioned for docking and cleared by the miner, begin approach
    if (clearedForDocking and targetPointInSpace:mag < 25 and relativeShipVelocity:mag < .2) {
      set shipModeReference to doDockingControl@.
      setServosToDockMode().
      set clearedForDocking to false.
    }

  } else {
    set pointingDir to "kill".
    findMinerShip().
  }

  local cometHoverFactor to V(0,0,0).
  if (cometTarget:isDead) {
    findCometTarget().
  } else {
    set vectorToComet to cometTarget:position.
    local distanceToComet to vectorToComet:mag.
    if (distanceToComet < cometHoverDistance + 20) {
      set cometHoverFactor to -vectorToComet:normalized * 20.
    }

    local angleRangeCoveredByComet to arctan(cometRadius / sqrt(cometRadius * cometRadius + distanceToComet * distanceToComet)).
    if (vang(minerHoverFactor, vectorToComet) < angleRangeCoveredByComet  and distanceToComet < distanceToTarget) {
      set minerHoverFactor to (vxcl(vectorToComet, minerHoverFactor)):normalized * desiredTargetApproachVelocity.
    }
  }

  local otherCraftAvoidance to V(0,0,0).
  local foundDeadVessel to false.
  if (not clearedForDocking and not inSafeZone) {
    local vslDistance to 0.
    local vslPosition to 0.
    local avoidanceForce to 0.
    for vsl in trackingVessels {
      if (vsl:isDead) {
        set foundDeadVessel to true.
      } else {
        set vslPosition to vsl:position.
        set vslDistance to max(10, vslPosition:mag - 40).
        set avoidanceForce to vslDistance / ((vslDistance / 10) * (vslDistance / 10) * (vslDistance / 10)).
        set otherCraftAvoidance to otherCraftAvoidance + vslPosition:normalized * avoidanceForce.
      }
    }

    if (foundDeadVessel) {
      findNearbyVessels().
    }
  }

  // print "minerAvoidanceFactor:    " + minerAvoidanceFactor:mag.
  // print "otherCraftAvoidance:     " + otherCraftAvoidance:mag.

  set otherCraftAvoidance to otherCraftAvoidance + minerAvoidanceFactor.

  // print "totalAvoidance:          " + otherCraftAvoidance:mag.
  // print "minerHoverFactor:        " + minerHoverFactor.
  // print "minerHoverMag:           " + minerHoverFactor:mag.
  // print "relativeShipVelocity:    " + relativeShipVelocity.
  // print "relativeShipVelocityMag: " + relativeShipVelocity:mag.
  // print "cometHoverFactor:        " + cometHoverFactor.
  // print "cometHoverFactor:mag:    " + cometHoverFactor:mag.


  // if (ship:name = "RCEnginePod2") {
  //   set diagArrow1 TO vecdraw(V(0,0,0), minerHoverFactor * 5, RGB(0,1,0), "minerHoverFactor", 1.0, TRUE, 0.2, TRUE, TRUE).
  //   set diagArrow2 TO vecdraw(V(0,0,0), cometHoverFactor * 5, RGB(0,0,1), "cometHoverFactor", 1.0, TRUE, 0.2, TRUE, TRUE).
  //   set diagArrow3 TO vecdraw(V(0,0,0), otherCraftAvoidance * 5, RGB(1,0,0), "otherCraftAvoidance", 1.0, TRUE, 0.2, TRUE, TRUE).
  //   wait .05.
  // }

  declare local directionToTravel to minerHoverFactor
    + relativeShipVelocity
    + cometHoverFactor
    - otherCraftAvoidance.

  local directionToTravelMag to directionToTravel:mag.
  if (directionToTravelMag > .1) {
    set engineDir to directionToTravel.
    set engineThrottle to directionToTravelMag * 30.
    // print "engineThrottle: " + engineThrottle.
    doEngineDirectionControl().
  } else {
    set engineThrottle to 0.
  }

  doEngineControl(15).

  wait 0.
}

function doCometVelocityStabilization {
  declare local relativeShipVelocity to cometTarget:velocity:orbit - ship:velocity:orbit.
  set engineThrottle to relativeShipVelocity:mag * 20.
  set engineDir to relativeShipVelocity.
  doEngineDirectionControl().
  doEngineControl(20).

  wait 0.
}

function doCleanup {

  unlock steering.
  FUELCELLS OFF.
  unlock throttle.

  hideArrows().
}

function doEngineDirectionControl {

  local controlPartFacing to controlPod:facing.
  local controlPartFacingForevector to controlPartFacing:forevector.
  local controlPartFacingTopVector to controlPartFacing:topvector.

  // A vector used as a ship reference for comparing vertical and horizontal angles
  // against the desired thrust direction.
  local compVec to vxcl(controlPartFacingForevector, engineDir).

  // It is not necessary for the center to make complete turns since it can
  // Face in either direction and the leftServo can swivel to account for it.
  // This is especially helpful in space where rotation around the axis is more problematic
  // local horizontalServoAngle to get360Angle(controlPartFacing:starvector, compVec).
  local horizontalServoAngle to vang(controlPartFacing:starvector, compVec).
  local vangToControlTop to vang(engineDir, controlPartFacingTopVector).

  if (vangToControlTop >= 90) {
    set horizontalServoAngle to -horizontalServoAngle.
  }

  // Don't set more often than needed as this is fairly expensive
  set horizontalServoAngle to round(horizontalServoAngle).
  if (horizontalServoAngle <> lastHorizontalServoAngle) {
    centralServoModule:setField("Target Angle", horizontalServoAngle).
    set lastHorizontalServoAngle to horizontalServoAngle.
  }

  local verticalServoAngle to vang(compVec, engineDir).

  // Make the servo angle a signed angle based on fore or aftward direction
  local vangToControlFore to vang(engineDir, controlPartFacingForevector).

  if (vangToControlFore > 90) {
    set verticalServoAngle to -verticalServoAngle.
  }

  set verticalServoAngle to round(verticalServoAngle).
  if (verticalServoAngle <> lastVerticalServoAngle) {
    leftServoModule:setField("Target Angle", verticalServoAngle).
    set lastVerticalServoAngle to verticalServoAngle.
  }

}

function doEngineControl {
  parameter engineThresholdAngle.

  // Throttle smoothing helps prevent servo bounce
  local throttleDiff to engineSmoothedThrottle - engineThrottle.

  if (throttleDiff < -5) {
    set throttleDiff to -5.
  } else if (throttleDiff > 5) {
    set throttleDiff to 5.
  }

  set engineSmoothedThrottle to max(0, min(100, engineSmoothedThrottle - throttleDiff)).

  set engineThrottle to engineSmoothedThrottle.

  if (engineThrottle <= 0) {
    if (nukeEngine1:ignition) {
      nukeEngine1:shutdown().
      set nukeEngine1:thrustLimit to 100.
      nukeEngine2:shutdown().
      set nukeEngine2:thrustLimit to 100.
      nukeEngine3:shutdown().
      set nukeEngine3:thrustLimit to 100.
      nukeEngine4:shutdown().
      set nukeEngine4:thrustLimit to 100.
    }

    return.
  }

  local steeringDirVectorAngle to vang(nukeEngine1:facing:forevector, engineDir).

  if (steeringDirVectorAngle < engineThresholdAngle) {
    if (not nukeEngine1:ignition) {
      nukeEngine1:activate().
      set nukeEngine1:thrustLimit to engineThrottle.
      nukeEngine2:activate().
      set nukeEngine2:thrustLimit to engineThrottle.
      nukeEngine3:activate().
      set nukeEngine3:thrustLimit to engineThrottle.
      nukeEngine4:activate().
      set nukeEngine4:thrustLimit to engineThrottle.
    } else {
      set nukeEngine1:thrustLimit to engineThrottle.
      set nukeEngine2:thrustLimit to engineThrottle.
      set nukeEngine3:thrustLimit to engineThrottle.
      set nukeEngine4:thrustLimit to engineThrottle.
    }
  } else {
    if (nukeEngine1:ignition) {
      nukeEngine1:shutdown().
      set nukeEngine1:thrustLimit to 100.
      nukeEngine2:shutdown().
      set nukeEngine2:thrustLimit to 100.
      nukeEngine3:shutdown().
      set nukeEngine3:thrustLimit to 100.
      nukeEngine4:shutdown().
      set nukeEngine4:thrustLimit to 100.
    }
  }
}

function printControlData {
  clearscreen.

  print "------------NukePod(4)--------------".
  // print "Ticker: " + ticker.
  print "LastMessage: " + lastMessage.
  print "DiagMessage: " + diagMessage.
  // print "Engine Throttle: " + engineThrottle.
  // print "TrackingVes: " + trackingVessels:length.
  print "CometTarget:  " + cometTarget.
  print "MinerName:   " + minerName.
  print "MinerShip:   " + minerShip.
  print "CoreMessages: " + core:messages:length.
  // print "TargetDockingPort: " + targetDockingPort.
  // print "DockingPortState: " + dockingPort:state.
  // print "ControlPod: " + controlPod.

  // print "---Laser---".
  // print laserRangeFinderModule:allfields.
  // print "BendX:    " + laserRangeFinderModule:getField("bend x").
  // print "BendY:    " + laserRangeFinderModule:getField("bend y").
  // print "Hit:      " + laserRangeFinderModule:getField("hit").
  // print "Layer:    " + laserRangeFinderModule:getField("layer").
  // print "Distance: " + laserRangeFinderModule:getField("distance").
  // print "laserAngles: " + laserAngles.
  // print "Laser Samples".
  // print laserRangeSamples.
  // print "ClosestLaserPoint: " + findClosestLaserPoint().
  // print "AngleOfSurface: " + findAngleOfSurface(findClosestLaserPoint(), LASER_ANGLE_RANGE).
  // print "angleOfSurface: " + angleOfSurface.
  // print "range: " + laserRangeSamples[8].
  // print "angularMom: " + ship:angularMomentum.
}

function handleInput {
  local charPressed to terminal:input:getchar().

  // set diagArrow3 TO vecdraw(V(0,0,0), -leftServo:facing:starvector * 10, RGB(1,0,0), "CentStar", 1.0, TRUE, 0.2, TRUE, TRUE).

  if (charPressed = "D") {
    handleMessage("DOCK").
  } else if (charPressed = "E") {
    handleMessage("COMET_EVAC").
  } else if (charPressed = "G") {
    handleMessage("GRAB").
  } else if (charPressed = terminal:input:UPCURSORONE) {
    set headingUpAngle to headingUpAngle + 10.
    handleSteeringTestMessage().
  } else if (charPressed = terminal:input:RIGHTCURSORONE) {
    set headingAngle to headingAngle + 10.
    handleSteeringTestMessage().
  } else if (charPressed = terminal:input:DOWNCURSORONE) {
    set headingUpAngle to headingUpAngle - 10.
    handleSteeringTestMessage().
  } else if (charPressed = terminal:input:LEFTCURSORONE) {
    set headingAngle to headingAngle - 10.
    handleSteeringTestMessage().
  }  else if (charPressed = "R") {
      set headingAngle to floor(360*RANDOM()).
      set headingUpAngle to floor(180*RANDOM()) - 90.
      handleSteeringTestMessage().
  } else if (charPressed  = "/") {
    set endProgram to true.
  } else if (charPressed = "S") {
    takeLaserSample().
  }

}

function handleSteeringTestMessage {
  if (headingAngle < 0) {
    set headingAngle to headingAngle + 360.
  } else if (headingAngle > 360) {
    set headingAngle to headingAngle - 360.
  }

  set engineDir to heading(headingAngle, headingUpAngle):forevector.
  doEngineDirectionControl().
  set diagArrow1 TO vecdraw(V(0,0,0), engineDir * 10, RGB(0,0,1), "To thrust", 1.0, TRUE, 0.2, TRUE, TRUE).
  lock steering to "kill".
}

function handleMessage {
  parameter msg.

  set lastMessage to msg.

  if (msg = "ATTACHED_REGROUP") {
    local dockingPortState to dockingPort:state.
    if (dockingPortState:contains("Docked") or dockingPortState:contains("PreAttached")) {
      dockingPort:undock().
      wait 0.1.
    }
    findNearbyVessels().
    set shipModeReference to doRegroupControl@.
    set pointingDir to "kill".
    set throttleValue to 1.
    doUndockingStartup().
  } else if (msg = "DOCK") {
    set clearedForDocking to true.
  } else if (msg:startsWith("POINT_TO")) {
    set shipModeReference to doPointControl@.
    local messageDetail to msg:split(",").
    set engineDir to V(messageDetail[1]:toNumber(), messageDetail[2]:toNumber(), messageDetail[3]:toNumber()).
    hideArrows().
  } else if (msg = "SPIN_CONTROL") {
    set shipModeReference to doSpinControl@.
    showTorqueVec().
  } else if (msg = "CREATE_SPIN") {
    set shipModeReference to doCreateSpinControl@.
  } else if (msg = "SHUTDOWN_ENGINES") {
    if (engineThrottle > 1) {
      set shipModeReference to doWait@.
      set engineDir to V(0,0,0).
      set engineSmoothedThrottle to 0.
      set engineThrottle to 0.
      doEngineDirectionControl().
      nukeEngine1:shutdown().
      set nukeEngine1:thrustLimit to 100.
      nukeEngine2:shutdown().
      set nukeEngine2:thrustLimit to 100.
      nukeEngine3:shutdown().
      set nukeEngine3:thrustLimit to 100.
      nukeEngine4:shutdown().
      set nukeEngine4:thrustLimit to 100.
      hideArrows().
    }
  } else if (msg = "LAUNCH") {
    dockingPort:undock().
    wait 0.1.
    findNearbyVessels().
    findCometTarget().
    set shipModeReference to doLaunchControl@.
    set pointingDir to cometTarget:position.
    set throttleValue to 1.
    doUndockingStartup().
  } else if (msg = "GRAB") {
    set shipModeReference to doGrabControl@.

    if (talonClawModuleAnimateGeneric:hasevent("arm")) {
      talonClawModuleAnimateGeneric:doevent("arm").
    }
    set laserHighPointDirection to V(0,0,0).
    laserRangeFinderModule:setField("enabled", true).
    set laserRangeSamples[8] to 1.  // Make sure it thinks the range is close until it gets a proper sample.
    setServosToDockMode().
    hideArrows().
  } else if (msg = "APPROACH") {
    findNearbyVessels().
    set shipModeReference to doLaunchControl@.
    set pointingDir to cometTarget:position.
    set throttleValue to 1.
    lock steering to pointingDir.
    lock throttle to throttleValue.
    doUndockingStartup().
    unlockServos().
  } else if (msg = "COMET_EVAC") {
    set shipModeReference to doCometEvacControl@.
  }
}

function showTorqueVec {
  if (SHOW_DIAG_ARROWS) {
    local angMom to angularMomentumInShipRaw().
    local torqueVec to vcrs(controlPod:position, angMom).
    set diagArrow1 TO vecdraw(controlPod:position, torqueVec:normalized * 80, RGB(0,1,1), "Torque", 1.0, TRUE, 0.2, TRUE, TRUE).
  }
}

function hideArrows {
  if (SHOW_DIAG_ARROWS) {
    if (diagArrow1 <> 0) {
      set diagArrow1:show to false.
    }

    if (diagArrow2 <> 0) {
      set diagArrow2:show to false.
    }

    if (diagArrow3 <> 0) {
      set diagArrow3:show to false.
    }
  }
}

function angularMomentumInShipRaw {
  local angMoRaw to ship:angularMomentum.
  return V(angMoRaw:x, -angMoRaw:z, angMoRaw:y) * ship:facing.
}

function doUndockingStartup {
  sas off.
  FUELCELLS ON.
  set SteeringManager:rollControlAngleRange to 180.
  findDroneParts().
  controlPod:controlFrom().
  set ship:loaddistance:orbit:load to 10001.
  set ship:loaddistance:orbit:unpack to 10000.
  lock steering to pointingDir.
  lock throttle to throttleValue.
  set ship:name to core:tag.
  setServosToFlyMode().
  set attachedOrDocked to false.
  unlockServos().
}

function findNearbyVessels {
  local nearbyVesselList to list().
  list targets in nearbyVesselList.

  set minerShip to 0.
  set minerShipSet to false.
  set cometTarget to 0.
  set cometRadius to 0.
  set cometHoverDistance to 0.
  set trackingVessels to list().

  for vsl in nearbyVesselList {
    if (vsl:distance < 10000 and vsl:mass < 10000) {
      trackingVessels:add(vsl).

      if (vsl:name = minerName) {
        set minerShip to vsl.
        set minerShipSet to true.
        set targetDockingPort to minerShip:partstagged(core:tag + "Target")[0].
      }
    } else if (vsl:name = cometName or vsl:name = "CometEgg") {
      set cometTarget to vsl.
      set cometRadius to cometTarget:bounds:extents:mag.
      set cometHoverDistance to cometRadius + COMET_HOVER_DISTANCE.
    }
  }
}

function findCollisionAvoidanceTrackingVessels {
  set closeTrackingVessels to list().

  for vsl in trackingVessels {
    if (vsl:distance < COLLISION_AVOIDANCE_LOAD_THRESHOLD) {
      closeTrackingVessels:add(vsl).
    }
  }
}

function findMinerShip {
  if (minerShip = 0) {
    local potentialMinerShips to 0.
    list targets in potentialMinerShips.

    for pms in potentialMinerShips {
      print pms.
      if (pms:name = minerName)
      if (pms:distance < 10000 and pms:mass < 20000 and pms:name = minerName) {
        print "Found it!".
        set minerShip to pms.
        set minerShipSet to true.
        set targetDockingPort to minerShip:partstagged(core:tag + "Target")[0].
        wait 1.
        break.
      }
    }
  }
}

function findCometTarget {
  declare local potentialCometEggs to 0.
  list targets in potentialCometEggs.
  for pce in potentialCometEggs {
    if (pce:distance < 10000 and pce:mass > 20000) {
      set cometTarget to pce.
      set cometRadius to cometTarget:bounds:extents:mag.
      set cometHoverDistance to cometRadius + COMET_HOVER_DISTANCE.
    }
  }
}

function findCometName {
  local potentialCometEggs to 0.
  local cometName to "NOT FOUND".

  list targets in potentialCometEggs.
  for pce in potentialCometEggs {
    if (pce:distance < 10000 and pce:mass > 20000) {
      set cometName to pce:name.
      break.
    }
  }

  return cometName.
}

function findDroneParts {
  if (centralServo <> 0) {
    return.
  }

  clearscreen.

  print "---------Finding Drone Parts---------".

  local allDockingPorts to core:vessel:dockingports.
  // print "allDockingPorts: " + allDockingPorts.

  local searchReference to ship.

  if (allDockingPorts:length > 1) {
    // Do full ship style search
    set targetDockingPort to ship:partstagged(core:tag + "Target")[0].

    set searchReference to targetDockingPort.
    set dockingPort to targetDockingPort:children[0].
  } else {
    // Do individual ship search.
    set dockingPort to allDockingPorts[0].
    set ship:Name to core:tag.
  }

  local grappleList to searchReference:partsnamed("GrapplingDevice").
  if (grappleList:length > 1) {
    set talonClaw to searchReference:partsTagged(core:tag + "Claw").
  } else {
    set talonClaw to grappleList[0].
  }

  set talonClawGrappleNode to talonClaw:getmodule("ModuleGrappleNode").
  set talonClawModuleAnimateGeneric to talonClaw:getmodule("ModuleAnimateGeneric").
  set talonClaw:tag to core:tag + "Claw".

  set centralServo to searchReference:partstagged("CentralServo")[0].
  set centralServoModule to centralServo:getModule("ModuleRoboticRotationServo").

  set leftServo to searchReference:partstagged("LeftServo")[0].
  set leftServoModule to leftServo:getModule("ModuleRoboticRotationServo").


  set dockingPort:tag to core:tag + "Dock".

  set controlPod to searchReference:partsnamedpattern("restock-drone-core")[0].
  set laserRangeFinder to searchReference:partsnamedpattern("distometer")[0].
  set laserRangeFinderModule to laserRangeFinder:getModule("LaserDistModule").

  set nukeEngines to searchReference:partstagged("RCEnginePodEngine").
  set nukeEngine1 to nukeEngines[0].
  set nukeEngine2 to nukeEngines[1].
  set nukeEngine3 to nukeEngines[2].
  set nukeEngine4 to nukeEngines[3].

  set podNumber to core:tag:replace("RCEnginePod", ""):toNumber().
  local minerNumber to floor((podNumber - 1) / NUMBER_OF_PODS) + 1.
  set minerName to "RCMiner" + minerNumber.

  local dockingPortState to dockingPort:state.
  if (dockingPortState:contains("Docked") or dockingPortState:contains("PreAttached") or talonClawGrappleNode:hasevent("release")) {
    set attachedOrDocked to true.
  } else {
    set attachedOrDocked to false.
  }

  print "  CenterServo:        " + centralServo:name.
  print "  CentralServoModule: " + centralServoModule:name.
  print "  ".
  Print "  LeftServo:          " + leftServo:name.
  print "  LeftServoModule:    " + leftServoModule:name.
  print "  ".
  print "  DockingPort:        " + dockingPort:name.
  print "  targetDockingPort:  " + targetDockingPort.
  print "  ControlPod:         " + controlPod:name.
  print "  ".
  print "  Claw:               " + talonClaw:name.
  print "  ClawNode:           " + talonClawGrappleNode:name.
  print "  Clawmodule:         " + talonClawModuleAnimateGeneric:name.
  print "  ".
  // print "  EnginesCount:       " + nukeEngines:length.
  print "  ".
  print "  MinerName:          " + minerName.
  print "  ".
  print "  CentralServoLock:   " + centralServoModule:hasAction("disengage servo lock").
  print "  CentralServoUnLock: " + centralServoModule:hasAction("engage servo lock").

  centralServoModule:setField("Target Angle", 90).
  leftServoModule:setField("Target Angle", -90).
}

function setServosToDockMode {
  centralServoModule:setField("Traverse Rate", 40).
  leftServoModule:setField("Traverse Rate", 60).
}

function setServosToFlyMode {
  centralServoModule:setField("Traverse Rate", 120).
  leftServoModule:setField("Traverse Rate", 140).
}

function getCubeSphere {
  parameter podNumber.

  local cubePoints to lexicon().
  cubePoints:add(1, V( 1,  1, -1)).
  cubePoints:add(2, V( 1, -1, -1)).
  cubePoints:add(3, V(-1,  1, -1)).
  cubePoints:add(4, V(-1, -1, -1)).
  cubePoints:add(5, V( 1,  1,  1)).
  cubePoints:add(6, V( 1, -1,  1)).
  cubePoints:add(7, V(-1,  1,  1)).
  cubePoints:add(8, V(-1, -1,  1)).

  return cubePoints[podNumber]:normalized.
}

// Assumes 8 points in laserRangeSamples
function findAngleOfSurface {
  parameter idxOfClosestLaserPoint.
  parameter laserAngleRange.

  local theta1 to laserAngleRange * 2.

  local idxOfOppositeSide to 0.

  if (idxOfClosestLaserPoint <= 3) {
    set idxOfOppositeSide to idxOfClosestLaserPoint + 4.
  } else {
    set idxOfOppositeSide to idxOfClosestLaserPoint - 4.
  }

  local d1 to laserRangeSamples[idxOfClosestLaserPoint].
  local d2 to laserRangeSamples[idxOfOppositeSide].
  local c1 to sin(theta1) * d1.
  local c2 to cos(theta1) * d1.
  local c3 to d2 - c2.
  local theta2 to (180 - theta1) / 2.
  local theta3 to arctan(c1 / c3).

  return theta2 - theta3.
}

// Assumes 8 points in laserRangeSamples
function findClosestLaserPoint {
  local closestDistance to 100000000000.
  local closestIdx to -1.

  for i in range(8) {
    if laserRangeSamples[i] < closestDistance {
      set closestDistance to laserRangeSamples[i].
      set closestIdx to i.
    }
  }

  return closestIdx.
}

function findRollDirectionOfLaserSample {
  parameter idx.
  parameter laserAngleRange.
  parameter laserPart.

  local angleSet to laserAngles[idx].
  local laserPartFacing to laserPart:facing.

  local rollDir to (angleSet:x / laserAngleRange * -laserPartFacing:starvector) + (angleSet:y / laserAngleRange * -laserPartFacing:topvector).

  return rollDir.
}

// Generates an 8 point "cone" for scanning.
// Plus one point for straight ahead range finding.
function setupLaserMap {
  parameter a.

  // Used to find interim points between full x and y that describe a complete
  // Circle/Cone
  local b to sqrt((a * a) / 2).

  // Laser pointer map
  // -x0+X
  // 7_0_1  -y
  // _____  -y
  // 6_8_2  0y
  // _____  +y
  // 5_4_3  +y
  // 8 is straight ahead.

  local buildMap to lexicon().

  buildMap:add(0, lexicon("x",  0, "y", -a)).
  buildMap:add(1, lexicon("x",  b, "y", -b)).
  buildMap:add(2, lexicon("x",  a, "y",  0)).
  buildMap:add(3, lexicon("x",  b, "y",  b)).
  buildMap:add(4, lexicon("x",  0, "y",  a)).
  buildMap:add(5, lexicon("x", -b, "y",  b)).
  buildMap:add(6, lexicon("x", -a, "y",  0)).
  buildMap:add(7, lexicon("x", -b, "y", -b)).
  buildMap:add(8, lexicon("x",  0, "y",  0)).

  return buildMap.
}

function unlockServos {
  centralServoModule:doAction("disengage servo lock", true).
  leftServoModule:doAction("disengage servo lock", true).
}
