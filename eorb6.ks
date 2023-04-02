@lazyglobal off.

// For driving orbital maneuvers of an eggship style craft (lots of small engines in all directions)

// For egg space maneuvers
declare global BASE_ENGINE_THRESHOLD_ANGLE to 30.
declare global BASE_MANEUVER_ENGINE_THRESHOLD_ANGLE to 1.
declare global STARTING_DISTANCE_FROM_DOCKING_PORT to 10.

declare global currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.

declare global endProgram to false.
declare global shipMode to "wait".

declare global deltaVRemaining to 0.

declare global engineList to list().
list engines in engineList.
set throttle to 1.

findManeuverEngines().

declare global maneuverDirection to "none".
declare global steeringDir to 0.

declare global pointingDir to 0.

declare global nextManeuver to 0.
declare global nextManeuverBurnTime to 0.

declare global engineThrottle to 100.

declare global updateCounter to 0.
declare global startingTime to time:seconds.
declare global shipTarget to 0.

declare global shipBounds to ship:bounds.
declare global targetBounds to 0.

declare global dockMessage to "".

declare global desiredDistanceToDockingPort to STARTING_DISTANCE_FROM_DOCKING_PORT.

lock steering to "kill".

declare global showArrow to 0.

until endProgram = true {

  set updateCounter to updateCounter + 1.

  set deltaVRemaining to constant:g0 * maneuverEngineIsp * ln ( ship:mass / ship:drymass ).

  if (hastarget and defined target) {
    set shipTarget to target.
  } else {
    set shipTarget to 0.
    set targetBounds to 0.
  }

  if (shipTarget <> 0 and ((shipTarget:typeName = "VESSEL" and shipTarget:unpacked) or (shipTarget:typeName <> "VESSEL" and shipTarget:ship:unpacked))) {
    if (targetBounds = 0) {
      if (shipTarget:typeName = "VESSEL") {
        set targetBounds to shipTarget:bounds.
      } else {
        set targetBounds to shipTarget:ship:bounds.
      }
    }
  } else {
    set targetBounds to 0.
  }

  manageManeuverNode().

  if (shipMode = "orbitalManeuver" and nextManeuver <> 0) {
    doOrbitalManeuver().
  } else if shipMode = "basicNav" {
    doBasicNav().
  } else if (shipMode = "dock") {
    doDockingControl().
  } else if (shipMode = "approach") {
    doApproachControl().
  } else {
    set steeringDir to 0.
    lock steering to "kill".
    set pointingDir to 0.
    set currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.
  }

  if (pointingDir <> 0) {
    lock steering to pointingDir.
  } else {
    lock steering to "kill".
  }

  doEngineControl().
  printControlData().
  handleInput().

  wait 0.
}.

function doEngineControl {

  if (shipMode = "basicNav" or shipMode = "dock" or shipMode = "approach") {
    for eng in engineList {
      declare local steeringDirVectorAngle to calculateSteeringVectorAngle(eng, steeringDir).

      if (steeringDir <> 0 and steeringDirVectorAngle < currentEngineThresholdAngle) {
        setEngineThrust(eng, engineThrottle).
      } else {
        shutdownEngine(eng).
      }
    }
  } else if (shipMode = "orbitalManeuver" and steeringDir <> 0) {
    for eng in maneuverEngines {
      setEngineThrust(eng, engineThrottle).
    }
  }

}

function doOrbitalManeuver {
  set steeringDir to nextManeuver:deltav.
  set pointingDir to steeringDir:direction.
  set currentEngineThresholdAngle to BASE_MANEUVER_ENGINE_THRESHOLD_ANGLE.

  if (nextManeuver:eta < (nextManeuverBurnTime / 2)) {
    declare local maxAcceleration to maxManeuverThrust / ship:mass.
    set engineThrottle to min(nextManeuver:deltav:mag / maxAcceleration, 1) * 100.
  } else {
    set engineThrottle to 0.
  }
}

function doApproachControl {
  if (shipTarget <> 0) {
    declare local vectorToTarget to 0.

    if (targetBounds <> 0) {
      declare local vectorBetweenShips to shipBounds:abscenter - targetBounds:abscenter.
      declare local desiredDistanceBetweenShips to (shipBounds:size:mag / 2) + (targetBounds:size:mag / 2) + 5.
      declare local targetPointInSpace to targetBounds:abscenter + (vectorBetweenShips:normalized * desiredDistanceBetweenShips).
      set vectorToTarget to targetPointInSpace - shipBounds:abscenter.
    } else {
      declare local vectorBetweenShips to ship:position - shipTarget:position.
      declare local targetPointInSpace to shipTarget:position + (vectorBetweenShips:normalized * 100).
      set vectorToTarget to targetPointInSpace - ship:position.
    }

    declare local distanceToTarget to vectorToTarget:mag.
    declare local desiredSpeedRelativeToTargetVelocity to ln(max(0, distanceToTarget) + 1) * 3.

    declare local relativeShipVelocity to 0.
    if (target:typename:contains("Part") or target:typename:contains("DockingPort")) {
      set relativeShipVelocity to target:ship:velocity:orbit - ship:velocity:orbit.
    } else {
      set relativeShipVelocity to target:velocity:orbit - ship:velocity:orbit.
    }

    declare local calcSteerDir to vectorToTarget:normalized * desiredSpeedRelativeToTargetVelocity + relativeShipVelocity.

    if (calcSteerDir:mag < 2) {
      set steeringDir to 0.
      set engineThrottle to 0.
    } else {
      set steeringDir to calcSteerDir.
      set engineThrottle to distanceToTarget + relativeShipVelocity:mag * 50.
    }

    // set showArrow TO VECDRAW(
    //   v(0,0,0),
    //   targetPointInSpace,
    //   RGB(0,1,0),
    //   "GoHere",
    //   1.0,
    //   TRUE,
    //   0.2,
    //   TRUE,
    //   TRUE
    // ).
  }
}

function doDockingControl {
  if (hastarget and shipTarget:name:contains("dockingport") and ship:controlpart:name:contains("dockingport") and shipTarget:nodeType = ship:controlpart:nodetype) {
    set dockMessage to "Docking".

    set pointingDir to lookdirup(-shipTarget:portfacing:forevector, shipTarget:portfacing:upvector).

    declare local targetPointInSpace to shipTarget:portfacing:forevector * desiredDistanceToDockingPort + shipTarget:position.
    declare local vectorToTarget to targetPointInSpace - ship:position.

    declare local distanceToTarget to vectorToTarget:mag.
    declare local desiredSpeedRelativeToTargetVelocity to ln(max(0, distanceToTarget) + 1) * 2.

    declare local relativeShipVelocity to target:ship:velocity:orbit - ship:velocity:orbit.

    declare local vangToTarget to vang(ship:facing:forevector, shipTarget:portfacing:forevector).

    declare local avoidanceFactor to V(0,0,0).

    if (distanceToTarget < 1.5 and relativeShipVelocity:mag < 2.5 and vangToTarget > 170) {
      set desiredDistanceToDockingPort to desiredDistanceToDockingPort - .05.
    } else {
      set desiredDistanceToDockingPort to STARTING_DISTANCE_FROM_DOCKING_PORT.

      if (vangToTarget <= 170) {
        declare local vectorBetweenShips to shipBounds:abscenter - targetBounds:abscenter.
        declare local distanceBetweenShipCenters to vectorBetweenShips:mag - (shipBounds:size:mag / 2) - (targetBounds:size:mag / 2).
        if (distanceBetweenShipCenters < 5 and vang(vectorBetweenShips, relativeShipVelocity) < 45) {
          set avoidanceFactor to vectorBetweenShips:normalized * 10.
        }
      }
    }

    // set showArrow TO VECDRAW(
    //   v(0,0,0),
    //   avoidanceFactor,
    //   RGB(1,0,0),
    //   "Avoid",
    //   1.0,
    //   TRUE,
    //   0.2,
    //   TRUE,
    //   TRUE
    // ).

    declare local calcSteerDir to vectorToTarget:normalized * desiredSpeedRelativeToTargetVelocity + relativeShipVelocity + avoidanceFactor.

    set steeringDir to calcSteerDir.

    set engineThrottle to distanceToTarget * 3 + relativeShipVelocity:mag * 10.

  } else {
    // TODO:  Should revert to hover control when it is ready
    set dockMessage to "Docking port mismatch".
    shutdownAllEngines().
  }

  if (ship:controlpart:name:contains("dockingport") and ship:controlpart:state:contains("Docked")) {
    set endProgram to true.
  }
}

function doBasicNav {
  if (maneuverDirection = "prograde") {
    set steeringDir to ship:prograde:forevector.
    lock steering to "kill".
    set pointingDir to 0.
    set currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.
    set engineThrottle to 100.
  } else if (maneuverDirection = "retrograde") {
    set steeringDir to ship:retrograde:forevector.
    lock steering to "kill".
    set pointingDir to 0.
    set currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.
    set engineThrottle to 100.
  } else if (maneuverDirection = "normal") {
    set steeringDir to vcrs(ship:velocity:orbit,-body:position).
    lock steering to "kill".
    set pointingDir to 0.
    set currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.
    set engineThrottle to 100.
  } else if (maneuverDirection = "antinormal") {
    set steeringDir to vcrs(ship:velocity:orbit,body:position).
    lock steering to "kill".
    set pointingDir to 0.
    set currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.
    set engineThrottle to 100.
  } else if (maneuverDirection = "radial") {
    declare local normalVec is vcrs(ship:velocity:orbit,-body:position).
    declare local radialVec is vcrs(ship:velocity:orbit,normalVec).
    set steeringDir to radialVec.
    lock steering to "kill".
    set pointingDir to 0.
    set currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.
    set engineThrottle to 100.
  } else if (maneuverDirection = "antiradial") {
    declare local anitNormalVec is vcrs(ship:velocity:orbit,body:position).
    declare local antiRadialVec is vcrs(ship:velocity:orbit,anitNormalVec).
    set steeringDir to antiRadialVec.
    lock steering to "kill".
    set pointingDir to 0.
    set currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.
    set engineThrottle to 100.
  }
}

function printControlData {
  clearscreen.

  print "Egg Space Control " + updateCounter + " / " + (time:seconds - startingTime).
  print "---ShipControl-------------".
  print "  ShipMode:                      " + shipMode.
  print "  ShipPosition:                  " + Ship:altitude.
  print "  deltaVRemaining                " + deltaVRemaining.
  print "  ManeuverDirection:             " + maneuverDirection.
  print "  SteeringManagerEnabled         " + SteeringManager:enabled.
  if (nextManeuver <> 0) {
    print "-------Next Maneuver----------------".
    print "  deltaV:                        " + nextManeuver:deltav:mag.
    // print "  nextManeuver:                  " + nextManeuver.
    print "  Eta:                           " + nextManeuver:eta.
    print "  manueverTime:                  " + nextManeuver:time.
    print "  CalcmaneuverTime:              " + nextManeuverBurnTime.
    // print "  burnTime:                      " + nextManeuver:deltav:mag / (maxManeuverThrust / ship:mass).
  }
  print "  maxManeuverThrust:             " + maxManeuverThrust.

  if (shipTarget <> 0) {
    print "Target:                        " + shipTarget.
    print "Port          :                " + shipTarget:name.
    // print "TargetNodeType:                " + shipTarget:nodeType.
    print "ShipSize:                      " + shipBounds:size:mag.
    if (targetBounds <> 0) {
      print "TargetSize:                    " + targetBounds:size:mag.
    }

  }

  if (shipMode = "dock") {
    print "DockMessage:                   " + dockMessage.
    print "desiredDistanceToDockingPort   " + desiredDistanceToDockingPort.
  }

  // print "  maneng:                        ".
  // print maneuverEngines.

}

function manageManeuverNode {
  if (hasnode) {
    set nextManeuver to nextnode.
    set nextManeuverBurnTime to burnTime(nextManeuver:deltav:mag).

    if (nextManeuverBurnTime < .25 and nextManeuver:eta < 0) {
      remove nextManeuver.
      set nextManeuver to 0.
      set nextManeuverBurnTime to 0.
      shutdownAllEngines().
    }
  } else {
    set nextManeuver to 0.
    set nextManeuverBurnTime to 0.
  }
}

function handleInput {
  if terminal:input:haschar {

    declare local charPressed to terminal:input:getchar().

    if (charPressed = "/") {
      set endProgram to true.
      unlock all.
      set throttle to 0.
      unlock throttle.
    }

    if (charPressed = "8") {
      set shipMode to "basicNav".
      set maneuverDirection to "prograde".
    }

    if (charPressed = "2") {
      set shipMode to "basicNav".
      set maneuverDirection to "retrograde".
    }

    if (charPressed = "4") {
      set shipMode to "basicNav".
      set maneuverDirection to "antinormal".
    }

    if (charPressed = "6") {
      set shipMode to "basicNav".
      set maneuverDirection to "normal".
    }

    if (charPressed = "7") {
      set shipMode to "basicNav".
      set maneuverDirection to "antiradial".
    }

    if (charPressed = "9") {
      set shipMode to "basicNav".
      set maneuverDirection to "radial".
    }

    if (charPressed = "+") {
      set shipMode to "orbitalManeuver".
      set maneuverDirection to 0.

      shutdownAllEngines().
    }

    if (charPressed = "0") {
      set shipMode to "dock".
      set desiredDistanceToDockingPort to STARTING_DISTANCE_FROM_DOCKING_PORT.
      set maneuverDirection to 0.
      shutdownAllEngines().
    }

    if (charPressed = "5") {
      set shipMode to "wait".
      set maneuverDirection to 0.

      shutdownAllEngines().
    }

    if (charPressed = ".") {
      set shipMode to "approach".
      set maneuverDirection to 0.

      shutdownAllEngines().
    }
  }
}

function setEngineThrust {
  parameter eng.
  parameter engThrustLimit.

  if (engThrustLimit <= 0) {
    shutdownEngine(eng).
  } else {
    if (not eng:ignition) {
      eng:activate().
    }

    set eng:thrustLimit to engThrustLimit.
  }
}

function calculateSteeringVectorAngle {
  parameter eng.
  parameter steerDir.

  if (steerDir = 0) {
    return 0.
  } else {
    return VANG(eng:facing:vector, steerDir).
  }
}

function shutdownEngine {
  parameter eng.

  if (eng:ignition) {
    eng:shutdown().
    set eng:thrustlimit to 100.
  }
}

function shutdownAllEngines {
  for eng in engineList {
    shutdownEngine(eng).
  }
}

function burnTime {
  parameter deltaV.

  declare local forceKgMS2 to maxManeuverThrust * 1000.  // (kg * m/s²)
  declare local massKg to ship:mass * 1000.

  return constant:g0 * massKg * maneuverIsp * (1 - constant:e^(-deltaV / (constant:g0 * maneuverIsp))) / forceKgMS2.
}

function findManeuverEngines {
  declare global maneuverEngines to list().
  for eng in engineList {
    declare local relToFrontVang to VANG(eng:facing:vector, ship:facing:forevector).

    if (relToFrontVang < BASE_MANEUVER_ENGINE_THRESHOLD_ANGLE) {
      maneuverEngines:add(eng).
    }
  }

  declare global maxManeuverThrust to 0.
  declare global maneuverEngineIsp to 0.
  for eng in maneuverEngines {
    setEngineThrust(eng, 100).
    set maxManeuverThrust to maxManeuverThrust + eng:maxthrust.
    set maneuverEngineIsp to eng:vacuumisp.
  }

  shutdownAllEngines().
  declare global maneuverIsp to maneuverEngines[0]:vacuumisp.
}
