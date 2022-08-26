@lazyglobal off.

// Worked well with OverComet_SH3_test2

set ship:loaddistance:orbit:load to 10001.
set ship:loaddistance:orbit:unpack to 10000.

local NUMBER_OF_PODS to 8.
local BASE_ENGINE_THRESHOLD_ANGLE to 70.
local COMET_HOVER_DISTANCE to 30.
local SURFACE_ANGLE_TOLERANCE to 30.
local SHOW_DIAG_ARROWS to false.

local cometName to findCometName().

core:part:getModule("kOSProcessor"):doEvent("Open Terminal").

local endProgram to false.
local diagMessage to "NONE".
local shipModeReference to doWait@.
local performingSpinDown to false.

local pointingDir to ship:facing.
local engineDir to 0.
local engineThrottle to 0.
local throttleValue to 0.
local maneuverDirection to 0.

local diagArrow1 to 0.
local diagArrow2 to 0.
local diagArrow3 to 0.

local enginePodCpus to list ().
local enginePodConnections to list().
local enginePodConnectionPool to lexicon().
local lastMessage to "NONE".

local cometTarget to 0.
local cometRadius to 0.
local cometHoverDistance to 0.
local trackingVessels to list().

local minerEngines to list().
local allTargetDockingPorts to list().
local controlPod to 0.
local talonClaw to 0.
local talonClawGrappleNode to 0.
local talonClawModuleAnimateGeneric to 0.
local laserRangeFinder to 0.
local laserRangeFinderModule to 0.

local activeDronePort to 0.

set SteeringManager:ROLLCONTROLANGLERANGE to 20.

findDroneParts().
findEnginePodCpus().

local LASER_ANGLE_RANGE to 4.
local laserSampleCurrentIdx to 0.
local laserRangeSamples to lexicon().
for i in range(9) {
  laserRangeSamples:add(i, 100000).
}
local laserHighPointDirection to V(0,0,0).
local angleOfSurface to 0.
local lastLaserSample to 0.

// Laser pointer laser angles for sampling
local laserAngles to setupLaserMap(LASER_ANGLE_RANGE).

until endProgram = true {

  shipModeReference().

  printControlData().

  if (terminal:input:haschar) {
    handleInput().
  }

  wait 0.
}

function doWait {
  // do nothing
}

function doDocking {

  if (activeDronePort = 0) {
    findNextDroneForDocking().

    if (activeDronePort = 0) {
      set shipModeReference to doWait@.
      return.
    }
  }

  if (activeDronePort:state:contains("Docked")) {
    set activeDronePort to 0.
  }

  set pointingDir to "kill".
}

function doCometEvacControl {
  local vectorToCenter to controlPod:position.
  set engineThrottle to 100.
  wait 5.
  talonClawGrappleNode:doEvent("release").
  wait 0.
  talonClawModuleAnimateGeneric:doevent("disarm").
  findDroneParts().
  controlPod:controlFrom().
  set ship:loaddistance:orbit:load to 10001.
  set ship:loaddistance:orbit:unpack to 10000.
  local engineDir to vectorToCenter.
  set pointingDir to "kill".
  lock steering to pointingDir.
  set throttleValue to 1.
  lock throttle to throttleValue.
  doEngineControl(engineDir).
  for eng in ship:partstagged("KickoffEngine") {
    eng:activate().
  }
  wait 5.
  set shipModeReference to doCometVelocityStabilization@.
  set ship:name to core:tag.
  findNearbyVessels().
  for eng in ship:partstagged("KickoffEngine") {
    eng:shutdown().
  }
}

function doRegroupControl {
  local retreatPosition to V(0,0,0).
  local desiredApproachVelocity to 0.
  local relativeShipVelocity to V(0,0,0).
  if (cometTarget:isdead) {
    findCometTarget().
  } else {
    local vectorToComet to cometTarget:position.
    set pointingDir to lookDirUp(-vectorToComet, ship:facing:upvector).
    local distanceToTargetCenterOfMass to vectorToComet:mag.

    if (distanceToTargetCenterOfMass > cometRadius + 200) {
      set shipModeReference to doCometVelocityStabilization@.
      return.
    }

    set retreatPosition to -vectorToComet:normalized * 700.
    set desiredApproachVelocity to min(20, retreatPosition:mag / 16).
    set relativeShipVelocity to cometTarget:velocity:orbit - ship:velocity:orbit.
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

  local directionToTravel to (retreatPosition:normalized * desiredApproachVelocity)
    + relativeShipVelocity
    + otherCraftAvoidance * -6.

  set engineThrottle to directionToTravel:mag * 50.
  doEngineControl(directionToTravel).
}

function doCometApproachControl {
  local vectorToComet to cometTarget:position.
  set pointingDir to -vectorToComet.

  local distanceToTargetCenterOfMass to vectorToComet:mag.
  local approachPosition to -vectorToComet:normalized * cometHoverDistance + vectorToComet.

  local distanceToApproachPosition to approachPosition:mag.
  local desiredApproachVelocity to min(20, distanceToApproachPosition / 16).

  declare local relativeShipVelocity to cometTarget:velocity:orbit - ship:velocity:orbit.

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

  local directionToTravel to (approachPosition:normalized * desiredApproachVelocity)
    + relativeShipVelocity
    + otherCraftAvoidance * -6.

  set engineThrottle to directionToTravel:mag * 50.
  doEngineControl(directionToTravel).

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

function doCometGrabbingControl {
  if ((cometTarget <> 0 and cometTarget:isdead) or cometTarget = 0) {
    findCometTarget().
  }

  takeLaserSample().

  local directionToTravel to V(0,0,0).
  local vectorToComet to cometTarget:position.
  set pointingDir to vectorToComet.

  local relativeShipVelocity to cometTarget:velocity:orbit - ship:velocity:orbit.

  local cometFacingVang to vang(ship:facing:forevector, vectorToComet).

  local upHillFactor to V(0,0,0).
  local desiredApproachVelocity to 5.
  local distanceToSurface to laserRangeSamples[8].
  if (distanceToSurface < 55) {
    if (cometFacingVang > 3) {
      set desiredApproachVelocity to -1.5.
      lock steering to pointingDir.
    } else {
      set desiredApproachVelocity to 1.5.
      if (angleOfSurface > SURFACE_ANGLE_TOLERANCE) {
        if (distanceToSurface < 30) {
          set vectorToComet to -vectorToComet.
        } else if (distanceToSurface < 35) {
          // Hover in a 5m range over the surface while scanning for a good spot.
          set vectorToComet to V(0,0,0).
        }
      }
    }
  }

  if (distanceToSurface < 150 and angleOfSurface > SURFACE_ANGLE_TOLERANCE) {
    set upHillFactor to laserHighPointDirection:normalized * .5.
  }

  set directionToTravel to vectorToComet:normalized * desiredApproachVelocity
    + relativeShipVelocity
    + upHillFactor.

  set engineThrottle to directionToTravel:mag * 50.
  doEngineControl(directionToTravel).

  if (talonClawGrappleNode:hasevent("release")) {
    set ship:name to "CometEgg".

    laserRangeFinderModule:setField("enabled", false).

    set shipModeReference to doWait@.
    set throttleValue to 0.
    unlock steering.
    unlock throttle.

    for eng in minerEngines {
      set eng:thrustLimit to 100.
      eng:shutdown().
    }
  }
}

function doSpinControl {
  local bestPositionedDroneList to sortDronesBySpinReductionTorque().

  if (SHOW_DIAG_ARROWS) {
    local angMo to angularMomentumInRaw().
    set diagArrow2 TO vecdraw(V(0,0,0), angMo:normalized * 900, RGB(1,0,0), "Ang. Mom.", 1.0, TRUE, 0.2, TRUE, TRUE).
  }

  // local cnt to 0.
  local msg to "SHUTDOWN_ENGINES".

  FROM {local x is 0.} UNTIL x >= (NUMBER_OF_PODS / 2) STEP {set x to x + 1.} DO {
    enginePodConnectionPool[bestPositionedDroneList[x]:tag]:sendMessage(msg).
  }

  set msg to "SPIN_CONTROL".
  FROM {local x is (NUMBER_OF_PODS / 2).} UNTIL x >= NUMBER_OF_PODS STEP {set x to x + 1.} DO {
    enginePodConnectionPool[bestPositionedDroneList[x]:tag]:sendMessage(msg).
  }

  wait .5.
}

function doCreateSpinControl {
  local bestPositionedDroneList to sortDronesBySpinReductionTorque().

  if (SHOW_DIAG_ARROWS) {
    local angMo to angularMomentumInRaw().
    set diagArrow2 TO vecdraw(V(0,0,0), angMo:normalized * 900, RGB(1,0,0), "AM", 1.0, TRUE, 0.2, TRUE, TRUE).
  }

  local msg to "SHUTDOWN_ENGINES".
  FROM {local x is 0.} UNTIL x >= (NUMBER_OF_PODS / 2) STEP {set x to x + 1.} DO {
    enginePodConnectionPool[bestPositionedDroneList[x]:tag]:sendMessage(msg).
  }

  set msg to "CREATE_SPIN".
  FROM {local x is (NUMBER_OF_PODS / 2).} UNTIL x >= NUMBER_OF_PODS STEP {set x to x + 1.} DO {
    enginePodConnectionPool[bestPositionedDroneList[x]:tag]:sendMessage(msg).
  }

  wait .5.
}

function doBasicNav {
  if (performingSpinDown) {
    doSpinControl().
    if (angularVel:mag < .02) {
      set performingSpinDown to false.
    }
    return.
  } else if (angularVel:mag > .1) {
    set performingSpinDown to true.
  }

  local desiredDirectionOfThrust to V(0,0,0).

  if (maneuverDirection = "prograde") {
    set desiredDirectionOfThrust to ship:prograde:forevector.
  } else if (maneuverDirection = "retrograde") {
    set desiredDirectionOfThrust to ship:retrograde:forevector.
  } else if (maneuverDirection = "normal") {
    set desiredDirectionOfThrust to vcrs(ship:velocity:orbit, -body:position).
  } else if (maneuverDirection = "antinormal") {
    set desiredDirectionOfThrust to vcrs(ship:velocity:orbit, body:position).
  } else if (maneuverDirection = "radial") {
    local shipVelocityOrbit to ship:velocity:orbit.
    local normalVec is vcrs(shipVelocityOrbit, -body:position).
    local radialVec is vcrs(shipVelocityOrbit, normalVec).
    set desiredDirectionOfThrust to radialVec.
  } else if (maneuverDirection = "antiradial") {
    local shipVelocityOrbit to ship:velocity:orbit.
    local anitNormalVec is vcrs(shipVelocityOrbit, body:position).
    local antiRadialVec is vcrs(shipVelocityOrbit, anitNormalVec).
    set desiredDirectionOfThrust to antiRadialVec.
  }

  if (SHOW_DIAG_ARROWS) {
    set diagArrow1 TO vecdraw(V(0,0,0), desiredDirectionOfThrust:normalized * 500, RGB(0,1 ,0), maneuverDirection, 1.0, TRUE, 0.2, TRUE, TRUE).
  }

  local bestPositionedDroneList to sortDronesByBestPositioning(desiredDirectionOfThrust).
  local msg to "SHUTDOWN_ENGINES".
  FROM {local x is 0.} UNTIL x >= (NUMBER_OF_PODS / 2) STEP {set x to x + 1.} DO {
    enginePodConnectionPool[bestPositionedDroneList[x]:tag]:sendMessage(msg).
  }

  set desiredDirectionOfThrust to desiredDirectionOfThrust:normalized.
  set msg to "POINT_TO," + desiredDirectionOfThrust:x + "," + desiredDirectionOfThrust:y + "," + desiredDirectionOfThrust:z.
  FROM {local x is (NUMBER_OF_PODS / 2).} UNTIL x >= NUMBER_OF_PODS STEP {set x to x + 1.} DO {
    enginePodConnectionPool[bestPositionedDroneList[x]:tag]:sendMessage(msg).
  }

  wait 1.
}

function doCometVelocityStabilization {
  declare local relativeShipVelocity to cometTarget:velocity:orbit - ship:velocity:orbit.
  set engineThrottle to relativeShipVelocity:mag * 150.
  doEngineControl(relativeShipVelocity).
}

function doEngineControl {
  parameter engineDir.

  if (engineDir = 0 or engineThrottle <= 0) {
    for eng in minerEngines {
      if (eng:ignition) {
        eng:shutdown().
        set eng:thrustlimit to 100.
      }
    }

    return.
  }

  declare local eng to 0.

  for eng in minerEngines {

    if (vang(eng:facing:vector, engineDir) < BASE_ENGINE_THRESHOLD_ANGLE) {
      if (not eng:ignition) {
        eng:activate().
      }

      set eng:thrustLimit to engineThrottle.
    } else {
      if (eng:ignition) {
        eng:shutdown().
        set eng:thrustlimit to 100.
      }
    }
  }
}

doCleanup().

function doCleanup {

  unlock steering.
  unlock throttle.

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

function printControlData {
  clearscreen.

  print "------------Nuke Miner(2)--------------".
  print "LastMessage: " + lastMessage.
  print "DiagMessage: " + diagMessage.
  // print "ControlPod: " + controlPod.
  // print "TrackingVessels: " + trackingVessels:length.
  // print "Drone CPUs/Connections: " + enginePodCpus:length + "/" + enginePodConnections:length.
  // print "cometTarget: " + cometTarget.
  // print "CometRadius: " + cometRadius.
  // print "cometHoverDistance: " + cometHoverDistance.
  // print "BurnTimePer1kMS: " + burnTime(1000).
  print "angleOfSurface: " + angleOfSurface.
  print "range: " + laserRangeSamples[8].
  print "AngularVelMag: " + angularVel:mag.
  // print "DrillModules: " + ship:partsnamed("RadialDrill")[0]:modules.
  // print "Fields: " + ship:partsnamed("RadialDrill")[0]:getModule("ModuleCometDrill"):allFields.
  // print "Actions: " + ship:partsnamed("RadialDrill")[0]:getModule("ModuleCometDrill"):allActions.

}

function handleInput {
  local charPressed to terminal:input:getchar().

  if (charPressed  = "/") {
    set endProgram to true.
  } else if (charPressed = "R") {
    broadcastLocalMessage("ATTACHED_REGROUP").
    broadcastMessage("ATTACHED_REGROUP").
    set shipModeReference to doRegroupControl@.
    findNearbyVessels().
  } else if (charPressed = "D") {
    controlPod:controlFrom().
    set shipModeReference to doDocking@.
    if (cometTarget <> 0) {
      set pointingDir to cometTarget:position.
    } else {
      set pointingDir to ship:facing:forevector.
    }
    lock steering to pointingDir.
  } else if (charPressed = "M") {
    rcs off.
    unlock throttle.
    unlock steering.
    controlPod:controlFrom().
    local shipFacingForevector to ship:facing:forevector.
    local pointString to "POINT_TO," + shipFacingForevector:x + "," + shipFacingForevector:y + "," + shipFacingForevector:z.
    broadcastLocalMessage(pointString).
    for eng in minerEngines {
      if (vang(shipFacingForevector, eng:facing:forevector) < 10) {
        eng:activate().
        set eng:thrustLimit to 100.
      } else {
        eng:shutdown().
        set eng:thrustLimit to 100.
      }
    }
  } else if (charPressed = "N") {
    rcs off.
    unlock throttle.
    unlock steering.
    controlPod:controlFrom().
    local shipFacingForevector to -ship:facing:forevector.
    local pointString to "POINT_TO," + shipFacingForevector:x + "," + shipFacingForevector:y + "," + shipFacingForevector:z.
    broadcastLocalMessage(pointString).
    for eng in minerEngines {
      if (vang(shipFacingForevector, eng:facing:forevector) < 10) {
        eng:activate().
        set eng:thrustLimit to 100.
      } else {
        eng:shutdown().
        set eng:thrustLimit to 100.
      }
    }
  } else if (charPressed = "L") {
    sas off.
    rcs on.
    broadcastLocalMessage("LAUNCH").
    wait 5.
    findNearbyVessels().
    set throttleValue to 1.
    lock throttle to throttleValue.
    set pointingDir to cometTarget:position.
    lock steering to pointingDir.
    controlPod:controlFrom().
    set shipModeReference to doCometApproachControl@.
  } else if (charPressed = "G") {
    rcs on.
    broadcastMessage("GRAB").
    if (talonClawModuleAnimateGeneric:hasevent("arm")) {
      talonClawModuleAnimateGeneric:doevent("arm").
    }
    talonClawGrappleNode:doAction("Control from here", true).
    laserRangeFinderModule:setField("enabled", true).
    set shipModeReference to doCometGrabbingControl@.
  } else if (charPressed = "A") {
    // Use when ships are saved surrounding a comet and need to start working again.
    sas off.
    rcs on.
    broadcastMessage("APPROACH").
    findNearbyVessels().
    set throttleValue to 1.
    lock throttle to throttleValue.
    set pointingDir to -cometTarget:position.
    lock steering to pointingDir.
    controlPod:controlFrom().
    set shipModeReference to doCometApproachControl@.
  } else if (charPressed = "Y") {
    for drill in ship:partsnamed("RadialDrill") {
      drill:getModule("ModuleCometDrill"):doAction("Start Comet Harvester", true).
    }
  } else if (charPressed = "U") {
    RADIATORS ON.
    FUELCELLS ON.
    DEPLOYDRILLS ON.
    ISRU ON.
  } else if (charPressed = "K") {
    set shipModeReference to doCometVelocityStabilization@.
  } else if (charPressed = "I") {
    RADIATORS OFF.
    FUELCELLS OFF.
    DEPLOYDRILLS OFF.
    ISRU OFF.
  } else if (charPressed = "8") {
    startupBasicNav().
    set maneuverDirection to "prograde".
  } else if (charPressed = "2") {
    startupBasicNav().
    set maneuverDirection to "retrograde".
  } else if (charPressed = "4") {
    startupBasicNav().
    set maneuverDirection to "antinormal".
  } else if (charPressed = "6") {
    startupBasicNav().
    set maneuverDirection to "normal".
  } else if (charPressed = "7") {
    startupBasicNav().
    set maneuverDirection to "antiradial".
  } else if (charPressed = "7") {
    startupBasicNav().
    set maneuverDirection to "antiradial".
  } else if (charPressed = "9") {
    startupBasicNav().
    set maneuverDirection to "radial".
  } else if (charPressed = "5") {
    set shipModeReference to doWait@.
    broadcastLocalMessage("SHUTDOWN_ENGINES").
    hideArrows().
  } else if (charPressed = "-") {
    set shipModeReference to doSpinControl@.
  } else if (charPressed = "+") {
    set shipModeReference to doCreateSpinControl@.
  } else if (charPressed = "[") {
    local servoList to ship:partstaggedpattern("servo").
    for servo in servoList {
      servo:getModule("ModuleRoboticRotationServo"):doAction("engage servo lock", true).
    }
  } else if (charPressed = "]") {
    local servoList to ship:partstaggedpattern("servo").
    for servo in servoList {
      servo:getModule("ModuleRoboticRotationServo"):doAction("disengage servo lock", true).
    }
  } else if (charPressed = "E") {
    set shipModeReference to doCometEvacControl@.
    broadcastLocalMessage("COMET_EVAC").
  }
}

function startupBasicNav {
  set shipModeReference to doBasicNav@.
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

function findNearbyVessels {
  local nearbyVesselList to list().
  list targets in nearbyVesselList.

  set trackingVessels to list().

  for vsl in nearbyVesselList {
    if (vsl:distance < 10000 and vsl:mass < 10000 and not vsl:name:contains("debris")) {
      trackingVessels:add(vsl).
    } else if (vsl:name = cometName or vsl:name = "CometEgg") {
      set cometTarget to vsl.
      set cometRadius to cometTarget:bounds:extents:mag.
      set cometHoverDistance to cometRadius + COMET_HOVER_DISTANCE.
    }
  }
}

function findCometName {
  declare local potentialCometEggs to 0.
  declare local cometName to "NOT FOUND".

  list targets in potentialCometEggs.
  for pce in potentialCometEggs {
    if (pce:distance < 10000 and pce:mass > 20000) {
      set cometName to pce:name.
      break.
    }
  }

  return cometName.
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

function findDroneParts {
  if (talonClaw <> 0) {
    return.
  }

  clearscreen.

  print "---------Finding Drone Parts---------".

  local searchReference to ship.

  local grappleList to searchReference:partstagged(core:tag + "Claw").
  set talonClaw to grappleList[0].
  set talonClawGrappleNode to grappleList[0]:getmodule("ModuleGrappleNode").
  set talonClawModuleAnimateGeneric to grappleList[0]:getmodule("ModuleAnimateGeneric").

  set controlPod to searchReference:partstagged(core:tag + "ControlPod")[0].
  set controlPod:tag to core:tag + "ControlPod".

  set minerEngines to searchReference:partstagged(core:tag + "Engine").

  set allTargetDockingPorts to searchReference:partstaggedpattern("Target").

  set laserRangeFinder to searchReference:partsTagged(core:tag + "Laser")[0].
  set laserRangeFinderModule to laserRangeFinder:getModule("LaserDistModule").

  // print "  DockingPort:        " + dockingPort:name.
  print "  ControlPod:         " + controlPod:name.
  print "  ".
  print "  Claw:               " + talonClaw:name.
  print "  ClawNode:           " + talonClawGrappleNode:name.
  print "  Clawmodule:         " + talonClawModuleAnimateGeneric:name.
  print "  ".
  print "  Miner Engines:      " + minerEngines:length.
  print "  ".
  print "  TargetDockingPorts: " + allTargetDockingPorts:length.
}

function broadcastLocalMessage {
  parameter msg.

  // print "Sending local messages...".

  for cnt in enginePodConnections {
    cnt:sendmessage(msg).
    // if (cnt:isconnected and cnt:sendmessage(msg)) {
    //   print "  Sent!".
    // } else {
    //   print "  Failed!".
    // }
  }
}

function broadcastMessage {
  parameter msg.

  print "Sending remote messages...".

  for cpu in enginePodCpus {
    local newCon to cpu:ship:connection.
    if (newCon:isconnected and newCon:sendmessage(msg)) {
      set diagMessage to newCon:destination + " - Sent!".
    } else {
      set diagMessage to newCon:destination + " - Failed!".
    }

  }
}

function findEnginePodCpus {
  if (enginePodCpus:length = NUMBER_OF_PODS and enginePodConnections:length = NUMBER_OF_PODS) {
    return.
  }

  local cpuCandidates to ship:partstaggedpattern("RCEnginePod").
  set enginePodCpus to list().
  set enginePodConnections to list().
  set enginePodConnectionPool to lexicon().
  local cnt to 0.
  for cpu in cpuCandidates {
    if cpu:hasModule ("kOSProcessor") {
      enginePodCpus:add(cpu).
      set cnt to cpu:getModule("kOSProcessor"):connection.
      enginePodConnectionPool:add(cpu:tag, cnt).
      enginePodConnections:add(cnt).
    }
  }

  if (enginePodCpus:length < NUMBER_OF_PODS) {
    local minerNumber to core:tag:replace("RCMiner", ""):toNumber().

    set enginePodCpus to list().
    set enginePodConnections to list().
    set enginePodConnectionPool to lexicon().

    local nearbyVesselList to list().
    list targets in nearbyVesselList.

    for tgt in nearbyVesselList {
      if (tgt:distance < 10000 and tgt:name:contains("RCEnginePod")) {
        local podNumber to tgt:name:replace("RCEnginePod", ""):toNumber().

        if (podNumber > (minerNumber - 1) * NUMBER_OF_PODS and podNumber <= (minerNumber - 1) * NUMBER_OF_PODS + NUMBER_OF_PODS) {
          local shipCpuCandidates to tgt:partstaggedpattern("RCEnginePod").
          for cpu in shipCpuCandidates {
            if (cpu:hasModule ("kOSProcessor")) {
              enginePodCpus:add(cpu).
              set cnt to cpu:getModule("kOSProcessor"):connection.
              enginePodConnectionPool:add(cpu:tag, cnt).
              enginePodConnections:add(cnt).
            }
          }
        }
      }
    }
  }
}

function findNextDroneForDocking {
  local closestDroneDistance to 90000.
  local closestDrone to 0.

  local possibleVessel to 0.
  local possibleVesselDistance to 0.

  for port in allTargetDockingPorts {
    if (not port:state:contains("Docked")) {
      set possibleVessel to vessel(port:tag:replace("Target", "")).
      set possibleVesselDistance to possibleVessel:distance.

      if (possibleVesselDistance < closestDroneDistance) {
        set closestDroneDistance to possibleVesselDistance.
        set closestDrone to possibleVessel.
        set activeDronePort to port.
      }
    }
  }

  if (closestDrone <> 0) {
    declare local newCon to closestDrone:connection.
    if (newCon:isconnected and newCon:sendmessage("DOCK")) {
      set diagMessage to newCon:destination + " - Sent!".
    } else {
      set diagMessage to newCon:destination + " - Failed!".
    }
  }
}

function sortDronesByBestPositioning {
  parameter desiredDroneDirection.

  local vangLex to lexicon().

  for cpu in enginePodCpus {
    vangLex:add(cpu:tag, vang(cpu:position, desiredDroneDirection)).
  }

  local sortedCpus is list().
  for cpu in enginePodCpus {
    for idx in range(sortedCpus:length) {
      if (vangLex[cpu:tag] < vangLex[sortedCpus[idx]:tag]) {
        sortedCpus:insert(idx, cpu).
        break.
      }
    }

    if (not sortedCpus:contains(cpu)) {
      sortedCpus:add(cpu).
    }
  }

  return sortedCpus.
}

function sortDronesBySpinReductionTorque {
  local spinLex to lexicon().
  local angMom to angularMomentumInRaw().

  // Sort condition is distance from the vector of angularMomentu,.
  // IE amount of appliable torque to reduce spin.
  for cpu in enginePodCpus {
    spinLex:add(cpu:tag, vxcl(angMom, cpu:position):mag).
  }

  local sortedCpus is list().
  for cpu in enginePodCpus {
    for idx in range(sortedCpus:length) {
      if (spinLex[cpu:tag] < spinLex[sortedCpus[idx]:tag]) {
        sortedCpus:insert(idx, cpu).
        break.
      }
    }
    if (not sortedCpus:contains(cpu)) {
      // if we didn't insert, it goes at the end
      sortedCpus:add(cpu).
    }
  }

  return sortedCpus. // return the matching vessels
}

function burnTime {
  parameter deltaV.

  local maxManeuverThrust to 960.
  local maneuverIsp to 800.

  declare local forceKgMS2 to maxManeuverThrust * 1000.  // (kg * m/s²)
  declare local massKg to ship:mass * 1000.

  return constant:g0 * massKg * maneuverIsp * (1 - constant:e^(-deltaV / (constant:g0 * maneuverIsp))) / forceKgMS2.
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

// From nuggreat, gets the angular momentum in the ships actual coordinate system
function angularMomentumInRaw {
  local am is ship:angularMomentum.
  set am to V(am:x,-am:z,am:y).
  return am * ship:facing.
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
