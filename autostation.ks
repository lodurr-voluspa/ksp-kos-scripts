@lazyglobal off.

// Script for allowing multiple ships to simultaneously dock with each other in close proximity
// after being released via staging.
// It requires that it have a liquid fuel engine pointed in each main direction (ie, NSEW, Up, Down).
// It also requires a docking port with a name xShipNamexControlDock on the ship, and a nearby
// ship to have a docking port with a name xShipNamexTarget.

// Fair warning, there is spaghetti, kludges, and, quite possibly, fudge factors.
// The documentation is also rubbish.  Enjoy!

// TODO:  Allow for fixed number of prior stages to allow for actual boosting to orbit
declare local timeToGo to false.
declare local ready to stage:ready.
on ready { print ready. set timeToGo to true. }
until timeToGo { set ready to stage:ready. wait 0. }

SAS off.

declare global BASE_ENGINE_THRESHOLD_ANGLE to 70.
declare global STARTING_DISTANCE_FROM_DOCKING_PORT to 8.

if (ship:name = "FuelPod" or ship:name = "HabHub") {
  set STARTING_DISTANCE_FROM_DOCKING_PORT to 15.
} else if (ship:name = "HabHub") {
  set STARTING_DISTANCE_FROM_DOCKING_PORT to 11.
}

declare global currentEngineThresholdAngle to BASE_ENGINE_THRESHOLD_ANGLE.

declare global endProgram to false.
declare global shipMode to "dock".

declare global engineList to list().
list engines in engineList.
set throttle to 1.

declare global steeringDir to 0.
declare global pointingDir to 0.
declare global engineThrottle to 100.
declare global shipTarget to 0.

declare global dockMessage to "".

declare global desiredDistanceToDockingPort to STARTING_DISTANCE_FROM_DOCKING_PORT.

lock steering to "kill".

declare global trackingVessels to list().
findNearbyVessels().

declare local controlParts to ship:PARTSTAGGED(ship:name + "ControlDock").
if (controlParts:length > 0) {
  controlParts[0]:controlfrom().
}

until endProgram = true {

  if (hastarget and defined target) {
    set shipTarget to target.
  } else {
    if (shipTarget = 0) {
      for vsl in trackingVessels {
        declare local targetPortList to vsl:PARTSTAGGED(ship:name + "Target").
        if (targetPortList:length > 0) {
          set shipTarget to targetPortList[0].
        }
      }
    }
  }

  doDockingControl().

  if (pointingDir <> 0) {
    lock steering to pointingDir.
  } else {
    lock steering to "kill".
  }

  doEngineControl().
  printControlData().

  wait 0.
}.

set throttle to 0.
unlock throttle.

function doEngineControl {
  for eng in engineList {
    declare local steeringDirVectorAngle to calculateSteeringVectorAngle(eng, steeringDir).

    if (steeringDir <> 0 and steeringDirVectorAngle < currentEngineThresholdAngle) {
      setEngineThrust(eng, engineThrottle).
    } else {
      shutdownEngine(eng).
    }
  }
}

function doDockingControl {
  if (shiptarget <> 0 and shipTarget:name:contains("dockingport") and ship:controlpart:name:contains("dockingport") and shipTarget:nodeType = ship:controlpart:nodetype) {
    set dockMessage to "Docking".

    set pointingDir to lookdirup(-shipTarget:portfacing:forevector, shipTarget:portfacing:upvector).

    if (shipTarget:ship:name <> "StationCore") {
      set desiredDistanceToDockingPort to STARTING_DISTANCE_FROM_DOCKING_PORT + 10.
    } else {
      set desiredDistanceToDockingPort to STARTING_DISTANCE_FROM_DOCKING_PORT.
    }

    declare local targetPointInSpace to shipTarget:portfacing:forevector * desiredDistanceToDockingPort + shipTarget:position.
    declare local vectorToTarget to targetPointInSpace - ship:position.

    declare local distanceToTarget to vectorToTarget:mag.
    declare local desiredSpeedRelativeToTargetVelocity to ln(max(0, distanceToTarget) + 1) * 0.5.

    declare local relativeShipVelocity to shipTarget:ship:velocity:orbit - ship:velocity:orbit.

    declare local vangToTarget to vang(ship:facing:forevector, shipTarget:portfacing:forevector).

    declare local otherCraftAvoidance to V(0,0,0).
    declare local dockingVectorToTarget to shipTarget:position - ship:position.

    for vsl in trackingVessels {
      // TODO:  Something off in the station core avoidance check
      if (vsl:isdead <> true and vsl:distance < 6 and (vsl:name <> "StationCore" or (vangToTarget > 175 and vang(dockingVectorToTarget, ship:facing:forevector) < 5))) {

        set dockMessage to "Avoiding, " + vsl.
        set otherCraftAvoidance to otherCraftAvoidance + vsl:direction:forevector * -5.
      }
    }

    declare local dockingFactor to V(0,0,0).
    declare local dockingVectorToTarget to shipTarget:position - ship:position.
    if (vangToTarget > 175 and vang(dockingVectorToTarget, ship:facing:forevector) < 5 and shipTarget:ship:name = "StationCore") {
      set dockingFactor to dockingVectorToTarget.
      set dockingFactor to dockingFactor:normalized * 2.
    }

    declare local calcSteerDir to vectorToTarget:normalized * desiredSpeedRelativeToTargetVelocity + relativeShipVelocity + otherCraftAvoidance:normalized + dockingFactor.

    set steeringDir to calcSteerDir.

    // TODO:  Improve fuel efficiency and tune throttle control
    set engineThrottle to calcSteerDir:mag * 150.

  } else {
    set dockMessage to "Docking port mismatch " + "HS: " + hastarget + " P:" + ship:controlpart.
    shutdownAllEngines().
  }

  if ((ship:controlpart:name:contains("dockingport") and ship:controlpart:state:contains("Docked")) or not ship:controlpart:name:contains("dockingport")) {
    set endProgram to true.
  }
}

function printControlData {
  clearscreen.

  if (shipTarget <> 0) {
    print "Target:                        " + shipTarget.
    print "Port          :                " + shipTarget:name.
  }

  print "DockMessage:                   " + dockMessage.
  print "desiredDistanceToDockingPort   " + desiredDistanceToDockingPort.
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

function findNearbyVessels {
  declare local nearbyVesselList to list().
  list targets in nearbyVesselList.

  for vsl in nearbyVesselList {
    if (vsl:distance < 3000 and not vsl:name:contains("debris")) {
      trackingVessels:add(vsl).
    }
  }
}
