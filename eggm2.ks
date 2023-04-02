@lazyglobal off.

// For driving an eggship style craft near the surface
// An eggship craft is one in which it has many small engines pointed in all directions.

// Constants
declare global DOWNWARD_THRUST_ANGLE_THRESHOLD to 55.      // The allowable angle cone for engines to qualify to thrust downward
declare global UPWARD_THRUST_ANGLE_THRESHOLD to 45.        // The alloweable angle cone for any upwards thrust to maintain ship height
declare global STEERING_THRUST_ANGLE_THRESHOLD to 55.      // The allowable angle cone for engines to qualify to thrust in a desired direction
declare global HORIZONTAL_THRUST_ANGLE_THRESHOLD to 55.    // The allowable angle cone for engines to qualify to thrust to stop horizontal motion
declare global CONTROL_ROTATION_FACTOR to -90.               // Rotates WASD controls from W pointing north -90 for VAB
declare global MAX_ANGULAR_MOMENTUM to 5.                  // Threshold to start automatically using engines to control spin

declare global READAHEAD_TIME_THRESHOLD to 20.            // Tweak this.  Higher is better for low g worlds at high speed.  THIS IS FOR KSC
// declare global READAHEAD_TIME_THRESHOLD to 80.            // Tweak this.  Higher is better for low g worlds at high speed.  THIS IS FOR MUN
declare global READAHEAD_TIME_THRESHOLD_HALF to READAHEAD_TIME_THRESHOLD / 2.

declare global ALTITUDE_INCREMENT_SMALL to 5.
declare global ALTITUDE_INCREMENT_LARGE to 50.

declare global AVAILABLE_DOWNWARD_THRUST_ESTIMATE to 1950.   // Estimate of the available downward thrust of all available engines for performing a hover slam.  Tweak per ship.

declare global targetGroundAltitude to 40.
declare global targetSeaLevelAltitude to round(ship:altitude).
declare global altitudeMatch to "sealevel".                // set to 'sealevel' or 'ground' to determine which hover altitude to use

declare global steerDir to 0.                              // A heading that the craft wants to go towards
declare global shipMode TO "wait".                        // ship mode to follow 'hover' allows for user control, 'land', 'launch', 'wait'
declare global horizontalStability to true.                // whether the ship should stop or allow horizontal motion
declare global upwardsHoverStability to false.             // whether the ship will fire engines upwards to maintain terrain height.
declare global downWardThrustLimit to 0.
declare global horizontalThrustLimit to 0.
declare global upwardsThrustLimit to 0.
declare global steeringThrustLimit to 0.
declare global stabilizingSpin to false.                   // whether the ship should actively use it's engines to prevent spin

declare global lockedSteering to heading(0, 90, 5).
lock steering to lockedSteering.

declare global verticalThrustAngleThresholdModifier to 0.
declare global horizontalThrustAngleThresholdModifier to 0.

// Ship reference data
declare global shipAngularVelocity to 0.
declare global radarHeight to alt:radar.
declare global upwardsVector to 0.
declare global shipBounds to ship:bounds.
declare global shipHalfHeight to alt:radar - shipBounds:bottomaltradar.

// Terrain tracking
declare global lastShipLatitude to ship:geoposition:lat.
declare global lastShipLongitude to ship:geoposition:lng.
declare global terrainReadAheadPostion to ship:geoposition.
declare global targetReadAheadGroundAltitude to 0.
declare global worried to false.
declare global worryFactor to 0.

// Target tracking
declare global followTarget to 0.
declare global relativeSpeedToTarget to 0.
declare global relativeVelocityVec to 0.
declare global desiredSpeedRelativeToTargetVelocity to 0.
declare global targetBounds to 0.
declare global hoverAboveHeight to 0.
declare global verticalDistanceBetweenShips to 0.
declare global followTargetHorizontalDistance to 0.
declare global desiredDir to 0.
declare global brakingDistance to 1400.    // TODO:  make this calculated.
declare global desiredFollowDistance to 14.
declare global relativeVelocityNotTowardsTarget to 0.
declare global followTargetSteeringThrustLimitOverride to 0.
declare global followTargetModeDiag to "".
declare global perchMode to false.
declare global aiCore to ship:controlpart.

// Engines
declare global engineList to list().
list engines in engineList.

lock throttle to 1.

declare global end_program to false.

// Spin control
declare global desiredCompassHeadingForRoll to 0.
declare global compassForShip to 0.
declare global spinControlNeeded to false.
declare global spinControlSignedMagnitude to 0.
declare global spinDir to 0.
declare global spinContThrottle to 0.

// Make sure this ship will load further out to use in cinematics
set ship:loaddistance:landed:load to 3701.
set ship:loaddistance:landed:unpack to 3700.

declare global g to constant:g * body:mass / body:radius^2.		// Gravity (m/s^2)

until end_program = true {

  set shipAngularVelocity to ship:angularvel.
  set radarHeight to alt:radar.
  set upwardsVector to up:forevector.

  aiCore:controlfrom().

  set worried to false.

  if (altitudeMatch = "sealevel") {
    set downWardThrustLimit to (((targetSeaLevelAltitude - ship:altitude) / 2) - verticalspeed) * 50.
  } else {
    groundHoverControl().
  }

  skyHoverControl().

  set downWardThrustLimit to max(0, min(100, downWardThrustLimit)).
  set horizontalThrustLimit to max(0, min(100, groundspeed * 25)).

  doTargetDeathCheck().

  printControlData().

  if (shipMode = "land") {
    doLandingControl().
    doEngineControl().
  } else if (shipMode = "hover") {
    doHoverControl().
    doEngineControl().
  } else if (shipMode = "launch") {
    doLaunchControl().
    doEngineControl().
  } else if (shipMode = "followtarget") {
    doFollowTargetControl().
    doEngineControl().
  } else {
    for eng in engineList {
      shutdownEngine(eng).
    }
  }

  handleInput().

  // Forces it to wait for a single physics tick
  wait 0.
}.

function doEngineControl {
  declare local shipToSurfaceRetrogradeVector to SHIP:SRFRETROGRADE:VECTOR.

  doSpinControl().

  for eng in engineList {

    declare local engineToUpVectorAngle to VANG(eng:facing:forevector, upwardsVector).

    if (engineToUpVectorAngle > (180 - DOWNWARD_THRUST_ANGLE_THRESHOLD)) {
      if (upwardsHoverStability and downWardThrustLimit <= 0 and upwardsThrustLimit > 0 and engineToUpVectorAngle > (180 - UPWARD_THRUST_ANGLE_THRESHOLD)) {
        // Aggressively follow terrain.
        if (not eng:ignition) {
          eng:activate().
        }
        set eng:thrustlimit to upwardsThrustLimit.
      } else {
        // Never waste fuel by firing downward pointing engines
        shutdownEngine(eng).
      }
    } else if (
      stabilizingSpin = true
      and (vcrs(eng:position, eng:facing:forevector) + angularvel):mag < angularvel:mag  // Find engine torque and see if this increases or decreases the angular momentum.  TODO:  Crude, could use some examination
    ) {
      setMaxEngineThrust(eng).
    } else if (
      steerDir <> 0
      and engineToUpVectorAngle > DOWNWARD_THRUST_ANGLE_THRESHOLD
      and engineToUpVectorAngle < (180 - DOWNWARD_THRUST_ANGLE_THRESHOLD)
      and calculateSteeringVectorAngle(eng, steerDir) < STEERING_THRUST_ANGLE_THRESHOLD
    ) {
      // Steer craft in desired direction
      if (not eng:ignition) {
        eng:activate().
      }
      set eng:thrustlimit to steeringThrustLimit.
    } else if (
      engineToUpVectorAngle < (DOWNWARD_THRUST_ANGLE_THRESHOLD + verticalThrustAngleThresholdModifier)
      and downWardThrustLimit > 0
    ) {
      // Hover craft at a specific altitude
      if (not eng:ignition) {
        eng:activate().
      }
      set eng:thrustlimit to downWardThrustLimit.
    } else if (
      horizontalStability = true
      and horizontalThrustLimit > 0
      and engineToUpVectorAngle > DOWNWARD_THRUST_ANGLE_THRESHOLD
      and VANG(eng:facing:vector, shipToSurfaceRetrogradeVector) < (HORIZONTAL_THRUST_ANGLE_THRESHOLD + horizontalThrustAngleThresholdModifier)
    ) {
      // Check horizontal motion
      if (not eng:ignition) {
        eng:activate().
      }
      set eng:thrustlimit to horizontalThrustLimit.
    } else if (spinControlNeeded
      and spinDir > 0
      and eng:tag = "SpinControlR") {
      // Control spin to the left.
      if (not eng:ignition) {
        eng:activate().
      }
      set eng:thrustLimit to spinContThrottle.
    } else if (spinControlNeeded
      and spinDir < 0
      and eng:tag = "SpinControlL") {
      // Conrol spin to the right
      if (not eng:ignition) {
        eng:activate().
      }
      set eng:thrustLimit to spinContThrottle.
    } else {
      shutdownEngine(eng).
    }
  }.
}

function doSpinControl {
  set compassForShip to vcompass(ship, ship:facing:starvector).
  declare local modDesiredCompassHeadingForRoll to desiredCompassHeadingForRoll - 90.
  if (modDesiredCompassHeadingForRoll < 0) {
    set modDesiredCompassHeadingForRoll to modDesiredCompassHeadingForRoll + 360.
  }

  // Translates to useful degrees -180 to 180 to determine which way to spin.
  declare local diff to mod(compassForShip - modDesiredCompassHeadingForRoll + 180, 360) - 180.
  if (diff < -180) {
    set spinControlSignedMagnitude to diff + 360.
  } else {
    set spinControlSignedMagnitude to diff.
  }

  declare local spinAngularVelocity to vdot(ship:facing:forevector, ship:angularvel).
  set spinControlNeeded to followTargetHorizontalDistance < 100 and (abs(spinControlSignedMagnitude) < 179 or abs(spinAngularVelocity > .0025)).

  // These values should be tweaked for individual ships based on flight characteristics
  // TODO:  find way to do a proper 'spinslam' by learning how to calculate the amount of torque each engine applies to a ship
  set spinDir to 7500 / (spinControlSignedMagnitude * abs(spinControlSignedMagnitude)) - spinAngularVelocity * 1.3.
  set spinContThrottle to abs(spinDir) * 100.
}

function doLaunchControl {

  if (followTarget <> 0) {
    set desiredCompassHeadingForRoll to followTarget:Heading + 90.
    set lockedSteering to heading(desiredCompassHeadingForRoll, 90, 0).
  }

  if (ship:altitude > ship:geoposition:terrainHeight + shipHalfHeight + 4) {
    set shipMode to "hover".
    gear off.
  }
}

function doLandingControl {

  gear on.

  if (not stabilizingSpin and not horizontalStability) {
    set horizontalStability to true.
  }

  declare local hoverslamDistance to 2 + shipHalfHeight.

  if (radarHeight < hoverslamDistance) {
    if (legs and verticalspeed < 3) {
      set targetSeaLevelAltitude to targetSeaLevelAltitude - 0.05.
    }
  } else {

    declare local maxDecel to (AVAILABLE_DOWNWARD_THRUST_ESTIMATE / ship:mass) - g.	// Maximum deceleration possible (m/s^2)
    declare local stopDist to ship:verticalspeed^2 / (2 * maxDecel).		// The distance the burn will require

    declare local stopDistAltitude to ship:geoposition:terrainHeight + stopDist.
    declare local hoverSlamAltitude to ship:geoposition:terrainHeight + hoverslamDistance.

    if (stopDistAltitude > hoverSlamAltitude) {
      set targetSeaLevelAltitude to stopDistAltitude.
    } else {
      set targetSeaLevelAltitude to hoverSlamAltitude.
    }

    set targetSeaLevelAltitude to max(stopDistAltitude, hoverSlamAltitude).

  }

  set altitudeMatch to "sealevel".

  if (targetSeaLevelAltitude < ship:geoposition:terrainHeight - 3.5) {
    set shipMode to "wait".
  }
}

function doHoverControl {
  set steeringThrustLimit to 100.

  if (followTarget <> 0) {
    set desiredCompassHeadingForRoll to followTarget:Heading + 90.
    set lockedSteering to heading(desiredCompassHeadingForRoll, 90, 0).
  }
}

function doFollowTargetControl {
  set horizontalStability to false.
  set altitudeMatch to "sealevel".

  calculateFollowSpeedAndDistance().
  calculateFollowTargetAltitude().
  manageChutes().
  setDesiredHorizontalMovementDirection().

  if (followTargetHorizontalDistance > brakingDistance) {
    fullBurnTowardTarget().
  } else if (followTargetHorizontalDistance < desiredFollowDistance) {
    preciseHoverOverTarget().
  } else {
    zeroInOnTarget().
  }

}

function calculateFollowSpeedAndDistance {
  declare local followTargetHorizontalVelocity to vxcl(upwardsVector, followTarget:velocity:surface).
  declare local shipHorizontalVelocity to vxcl(upwardsVector, ship:velocity:surface).

  set relativeVelocityVec to followTargetHorizontalVelocity - shipHorizontalVelocity.

  set relativeSpeedToTarget to relativeVelocityVec:mag.
  set followTargetHorizontalDistance to vxcl(upwardsVector, followTarget:position):mag.

  if (followTargetHorizontalDistance < 20) {
    set desiredSpeedRelativeToTargetVelocity to ln(max(0, followTargetHorizontalDistance - desiredFollowDistance) + 1) * 6.
  } else {
    set desiredSpeedRelativeToTargetVelocity to ln(max(0, followTargetHorizontalDistance - desiredFollowDistance) + 1) * 50.
  }

  if (followTarget <> 0 and followTarget:unpacked) {
    if (targetBounds = 0) {
      set targetBounds to followTarget:bounds.
    }
    set verticalDistanceBetweenShips to shipBounds:bottomalt - body:altitudeOf(targetBounds:FURTHESTCORNER(upwardsVector)).
  } else {
    set targetBounds to 0.
  }
}

function calculateFollowTargetAltitude {
    setStartingHoverHeightOverTarget().
}

function manageChutes {
  if (not chutes and followTargetHorizontalDistance < brakingDistance and groundspeed > 150) {
    chutes on.
  } else if (chutes and relativeSpeedToTarget < 60) {
    ag6 on.
  }
}

function setDesiredHorizontalMovementDirection {
  // declare local headingVector to heading(followTarget:Heading, 0):forevector.
  // declare local relativeVelocityNotTowardsTarget to vxcl(relativeVelocityVec, headingVector).
  //
  // if (relativeVelocityNotTowardsTarget:mag > 5) {
  //   set desiredDir to relativeVelocityNotTowardsTarget.
  //   set followTargetSteeringThrustLimitOverride to 100.
  // } else {
  //   set desiredDir to (headingVector * desiredSpeedRelativeToTargetVelocity) + (relativeVelocityVec * 1).
  //   set followTargetSteeringThrustLimitOverride to 0.
  // }
  //
  // // Try to make sure it doesn't end up spinning around target instead of working with target.
  // // if (relativeVelocityVec:mag > 20 and followTargetHorizontalDistance < 50) {
  // //   set desiredDir to relativeVelocityVec.
  // // } else {
  // //   set desiredDir to (heading(followTarget:Heading, 0):forevector * desiredSpeedRelativeToTargetVelocity) + (relativeVelocityVec * 1).
  // // }

  set desiredDir to (heading(followTarget:Heading, 0):forevector * desiredSpeedRelativeToTargetVelocity) + (relativeVelocityVec * 1).
}

function fullBurnTowardTarget {
  set desiredCompassHeadingForRoll to followTarget:Heading + 90.
  set lockedSteering to heading(desiredCompassHeadingForRoll, 90, 0).

  // Max ground speed
  if (groundspeed < 300) {
    set steeringThrustLimit to 100.
    set steerDir to heading(followTarget:Heading, 0).
  } else {
    set steeringThrustLimit to 100.
    set steerDir to 0.
  }
}

function preciseHoverOverTarget {
  set steeringThrustLimit to relativeVelocityVec:mag * 100.
  set steerDir to relativeVelocityVec:direction.
  // set desiredCompassHeadingForRoll to compass_for(followTarget).
  set desiredCompassHeadingForRoll to compass_for(followTarget) + 90.
  set lockedSteering to heading(desiredCompassHeadingForRoll, 90, 0).
}

function zeroInOnTarget {
  set followTargetModeDiag to "n/a".

  declare local headingVector to heading(followTarget:Heading, 0):forevector.
  declare local relativeVelocityNotTowardsTarget to vxcl(relativeVelocityVec, headingVector).

  declare local maxDecel to 1200 / ship:mass.  // An an estimate of max thrust available in any direction..
  declare local stopDist to (relativeVelocityVec:mag)^2 / (2 * maxDecel).

  if (followTargetHorizontalDistance < 20) {
    set steerDir to desiredDir:direction.
    if (vang(relativeVelocityVec, heading(followTarget:Heading, 0):forevector) < 160) {
      set steeringThrustLimit to 100.
    } else {
      set steeringThrustLimit to min(110, abs(desiredSpeedRelativeToTargetVelocity - relativeVelocityVec:mag)* 10).
    }
  } else {
    if (vang(relativeVelocityVec, heading(followTarget:Heading, 0):forevector) < 130) {
      set steeringThrustLimit to 100.
      set steerDir to relativeVelocityVec:direction.
      set followTargetModeDiag to "BadVelAngleBurnRetrogradeToTarget".
    } else if (relativeVelocityNotTowardsTarget:mag > 5) {
      set steeringThrustLimit to 100.
      set steerDir to relativeVelocityNotTowardsTarget:direction.
      set followTargetModeDiag to "CorrectVelocityToTarget".
    } else {
      if (followTargetHorizontalDistance < stopDist) {
        set steeringThrustLimit to 100.
        set steerDir to relativeVelocityVec:direction.
        set followTargetModeDiag to "HorizontalSlam".
      } else {
        set steeringThrustLimit to 100.
        set steerDir to desiredDir:direction.
        set followTargetModeDiag to "Regular".
      }
    }
  }

  set desiredCompassHeadingForRoll to compass_for(followTarget) + 90.
  // set desiredCompassHeadingForRoll to compass_for(followTarget).
  set lockedSteering to heading(desiredCompassHeadingForRoll, 90, 0).

  // if (followTargetSteeringThrustLimitOverride <> 0) {
  //   set steeringThrustLimit to followTargetSteeringThrustLimitOverride.
  // }
}

function doTargetDeathCheck {
  // If the target is dead stop following it.
  if (followtarget <> 0 and followTarget:isdead) {
    set followTarget to 0.
    set targetBounds to 0.

    if (shipMode = "followTarget") {
      set targetSeaLevelAltitude to targetSeaLevelAltitude + 5.
      set shipMode to "hover".
      set horizontalStability to true.
      set steerDir to 0.
    }
  }
}

function groundHoverControl {
  declare local shipCurrentLatitude to ship:geoposition:lat.
  declare local shipCurrentLongitude to ship:geoposition:lng.

  declare local latDiff to shipCurrentLatitude - lastShipLatitude.
  declare local lonDiff to shipCurrentLongitude - lastShipLongitude.
  set lastShipLatitude to shipCurrentLatitude.
  set lastShipLongitude to shipCurrentLongitude.

  set terrainReadAheadPostion to latlng(shipCurrentLatitude + (latDiff * READAHEAD_TIME_THRESHOLD_HALF), shipCurrentLongitude + (lonDiff * READAHEAD_TIME_THRESHOLD_HALF)).
  declare local terrainReadAheadPostionLong to latlng(shipCurrentLatitude + (latDiff * READAHEAD_TIME_THRESHOLD), shipCurrentLongitude + (lonDiff * READAHEAD_TIME_THRESHOLD)).

  declare local terrainReadAheadHeight to max(terrainReadAheadPostion: terrainHeight, terrainReadAheadPostionLong:terrainHeight).
  set targetReadAheadGroundAltitude to max(targetGroundAltitude, targetGroundAltitude + terrainReadAheadHeight - ship:geoposition:terrainHeight).

  if (groundspeed > 10 and radarHeight < 15) {
    // Emergency burn
    set downWardThrustLimit to 10000.
  } else {
    // Standard hover control TODO: may be better solution
    set downWardThrustLimit to (((targetReadAheadGroundAltitude - (radarHeight)) / 2) - verticalspeed) * 50.

    // Try to prevent excessive, unrecoverable descent speed
    if (downWardThrustLimit <= 0) {
      set worryFactor to (-1 * min(0.000001, verticalspeed)) / radarHeight.

      if (worryFactor > 0.1) {
        set downWardThrustLimit to 200 * min(1, worryFactor * 10).
        set worried to true.
      }
    } else {
      set worryFactor to 0.
    }

  }
}

function skyHoverControl {
  // Inverted version of downward thrust control  TODO:  crude
  if (upwardsHoverStability and (not worried) and verticalspeed > -10 and radarHeight - targetReadAheadGroundAltitude > 20) {
    set upwardsThrustLimit to max(0, min(100, (((radarHeight - targetReadAheadGroundAltitude) / 2) + verticalspeed) * 100)).
  } else {
    set upwardsThrustLimit to 0.
  }
}

function setStartingHoverHeightOverTarget {
  set targetSeaLevelAltitude to followTarget:altitude.

  // // TODO:  Add terrain height conflict resolution
  // declare local heightAboveTargetToHover to 0.
  //
  // if (targetBounds <> 0) {
  //   set heightAboveTargetToHover to body:altitudeOf(targetBounds:FURTHESTCORNER(upwardsVector)) + 10 + ship:altitude - shipBounds:bottomalt.
  // } else {
  //   set heightAboveTargetToHover to 20 + ship:altitude - shipBounds:bottomalt.
  // }
  //
  // if (followTarget:altitude - followTarget:geoposition:terrainHeight > 20) {
  //   set heightAboveTargetToHover to heightAboveTargetToHover + 60.
  // }
  //
  // declare local terrainHeightMode to ship:geoposition:terrainHeight + 10.
  // set targetSeaLevelAltitude to max(heightAboveTargetToHover, terrainHeightMode).
}

function printControlData {
  clearscreen.


  print "---Control Mode---".
  print "  Mode:                 " + shipMode.
  if (steerDir = 0) {
    print "  Steering:             disengaged.".
  } else {
    print "  Steering to:          " + steerDir.
  }
  print "  Steering thrust lim:  " + steeringThrustLimit.
  print "  Stability-Spin:       " + stabilizingSpin.
  print "  Stablity-Horizontal:  " + horizontalStability.
  print "  Stability-Groundflw:  " + upwardsHoverStability.
  print "  Ship Fac              " + ship:facing.
  print "  RollAngularVel:       " + VDOT(SHIP:FACING:FOREVECTOR,SHIP:ANGULARVEL).
  print "  spinControlSignedMag  " + spinControlSignedMagnitude.
  print "  shipHalfHeight:       " + shipHalfHeight.

  print "  ----Target------".

  if (followTarget <> 0) {
    print "  Relspd                " + relativeSpeedToTarget.
    print "  FollowTarget:         " + followTarget.
    print "  FollowTarget Dist:    " + vxcl(upwardsVector, followTarget:position):mag.
    print "  DesSpdRelToTarget:    " + desiredSpeedRelativeToTargetVelocity.
    print "  FollowTargetHeading   " + followTarget:heading.
    print "  ShipFacingRoll:       " + facing:roll.
    print "  ShipBearing:          " + followTarget:bearing.
    print "  ShipComp/DesComp      " + desiredCompassHeadingForRoll + "/" + compassForShip.
    print "  HorizontalDistance    " + followTargetHorizontalDistance.
    print "  followTargetModeDiag  " + followTargetModeDiag.
    if (targetBounds <> 0) {
      print "  verticalDistanceBetweenShips: " + verticalDistanceBetweenShips.
    }
  }

  print "---Altitude Control---".
  print "  Altitude Mode:        " + altitudeMatch.
  if (altitudeMatch = "sealevel") {
    print "  Target Altitude:      " + targetSeaLevelAltitude.
    print "  Sea-level Altitude:   " + round(ship:altitude).
  } else {
    print "  Target Altitude:      " + targetGroundAltitude.
    print "  Radar Altitude:       " + round(radarHeight).
    print "  Projected Altitude:   " + round(targetReadAheadGroundAltitude).
    print "  Projected/Act Diff    " + round(targetReadAheadGroundAltitude - radarHeight).
    print "  Vertical Speed:       " + verticalspeed.

    print "  Worried:              " + worried.
    print "  Worry Factor:         " + worryFactor.
  }

  print "---Location---".
  print "  Ship-Latitude:        " + round(ship:latitude, 6).
  print "  Ship-Longitude:       " + round(ship:Longitude, 6).

  print "---Downwards Control---".
  print "  Thrust Limit:         " + round(downWardThrustLimit, 2).
  print "  Angle Thresh. Mod:    " + verticalThrustAngleThresholdModifier.

  if (stabilizingSpin) {
    print "---Stabilizing Spin---".
    print "  Angular Veclocity     " + round(angularvel:mag, 4).
  }

  if (horizontalStability) {
    print "---Horizontal Control---".
    print "  Thrust Limit:         " + round(horizontalThrustLimit, 2).
    print "  Angle Thresh. Mod:    " + horizontalThrustAngleThresholdModifier.
  }

  if (upwardsHoverStability) {
    print "---Upwards Control---".
    print "  Thrust Limit:         " + upwardsThrustLimit.
  }

  print "Load:      " + ship:loaddistance:landed:load.
  // print "Unload:    " + ship:loaddistance:landed:unload.
  // print "Unpack:      " + ship:loaddistance:landed:unpack.
  print "Pack:    " + ship:loaddistance:landed:pack.
}

function handleInput {
  if terminal:input:haschar {

    declare local charPressed to terminal:input:getchar().

    if (charPressed = "/") {
      set end_program to true.
      unlock all.
    }

    if (charPressed = "1") {
      if (altitudeMatch = "sealevel") {
        set altitudeMatch to "ground".
      } else {
        set altitudeMatch to "sealevel".
        set targetSeaLevelAltitude to ship:altitude.
      }
    }

    if (charPressed = "T") {
      declare local nearbyVesselList to list().
      declare local filteredVesselList to list().
      list targets in nearbyVesselList.

      for vsl in nearbyVesselList {
        if (vsl:distance < 8000) {
          filteredVesselList:add(vsl).
        }
      }

      if (followTarget = 0 and filteredVesselList:length > 0) {
        set followTarget to filteredVesselList[0].

      } else if (filteredVesselList:length > 0) {
        declare local idx to filteredVesselList:indexof(followTarget).
        if (idx > -1) {
          declare local newIdx to idx + 1.
          if (newIdx >= filteredVesselList:length) {
            set newIdx to 0.
          }
          set followTarget to filteredVesselList[newIdx].
        } else {
          set followTarget to filteredVesselList[0].
        }


      } else {
        set followTarget to 0.
        set targetBounds to 0.
        set shipMode to "hover".
      }
    }

    if (charPressed = "A") {
      if (altitudeMatch = "sealevel") {
        set targetSeaLevelAltitude to targetSeaLevelAltitude - ALTITUDE_INCREMENT_SMALL.
      } else {
        set targetGroundAltitude to targetGroundAltitude - ALTITUDE_INCREMENT_SMALL.
      }
    }

    if (charPressed = "Q") {
      if (altitudeMatch = "sealevel") {
        set targetSeaLevelAltitude to targetSeaLevelAltitude + ALTITUDE_INCREMENT_SMALL.
      } else {
        set targetGroundAltitude to targetGroundAltitude + ALTITUDE_INCREMENT_SMALL.
      }
    }

    if (charPressed = "S") {
      if (altitudeMatch = "sealevel") {
        set targetSeaLevelAltitude to targetSeaLevelAltitude - ALTITUDE_INCREMENT_LARGE.
      } else {
        set targetGroundAltitude to targetGroundAltitude - ALTITUDE_INCREMENT_LARGE.
      }
    }

    if (charPressed = "W") {
      if (altitudeMatch = "sealevel") {
        set targetSeaLevelAltitude to targetSeaLevelAltitude + ALTITUDE_INCREMENT_LARGE.
      } else {
        set targetGroundAltitude to targetGroundAltitude + ALTITUDE_INCREMENT_LARGE.
      }
    }


    if (charPressed = "L") {
      // bays off.
      set steerDir to 0.

      // set targetGroundAltitude to ship:altitude.

      if (shipMode = "wait") {

        lights on.
        gear off.
        set shipMode to "launch".
        set altitudeMatch to "sealevel".
        // set targetSeaLevelAltitude to ship:altitude + 25.
        set targetSeaLevelAltitude to shipBounds:bottomalt + 10.
        set horizontalStability to true.
      } else {
        set altitudeMatch to "sealevel".
        set targetSeaLevelAltitude to ship:altitude.
        set shipMode to "land".
        bays on.

        // if (angularvel:mag > 0.5) {
        //   set stabilizingSpin to true.
        // }
      }
    }

    if (charPressed = "H") {
      set shipMode to "hover".
      set steerDir to 0.
    }

    if (charPressed = "J") {
      set shipMode to "wait".
    }

    if (charPressed = "F") {
      if (followTarget <> 0) {
        set shipMode to "followtarget".
        gear off.
        lights on.

        setStartingHoverHeightOverTarget().

        // declare local terrainHeightMode to shipBounds:bottomalt + 10.
        // declare local currentHeight to ship:altitude.
        // set targetSeaLevelAltitude to max(heightAboveTargetToHover, max(terrainHeightMode, currentHeight)).
      }
    }

    if (charPressed = "7") {
    	set horizontalStability to not horizontalStability.
    }

    if (charPressed = "8") {
      set upwardsHoverStability to not upwardsHoverStability.
    }

    if (charPressed = "0") {
    	set stabilizingSpin to true.
    }

    if (charPressed = terminal:input:UPCURSORONE) {
      set steerDir to heading(0 + CONTROL_ROTATION_FACTOR, 0).
      set horizontalStability to false.
    }

    if (charPressed = terminal:input:RIGHTCURSORONE) {
      set steerDir to heading(90 + CONTROL_ROTATION_FACTOR, 0).
      set horizontalStability to false.
    }

    if (charPressed = terminal:input:DOWNCURSORONE) {
      set steerDir to heading(180 + CONTROL_ROTATION_FACTOR, 0).
      set horizontalStability to false.
    }

    if (charPressed = terminal:input:LEFTCURSORONE) {
      set steerDir to heading(270 + CONTROL_ROTATION_FACTOR, 0).
      set horizontalStability to false.
    }

    // Brake over current point
    if (charPressed = "D") {
      set steerDir to 0.
      set horizontalStability to true.
    }

    // Hover coast
    if (charPressed = "E") {
      set steerDir to 0.
      set horizontalStability to false.
    }

    if (charPressed = "[") {
      set lockedSteering to heading(90, 90, 0).
      set desiredCompassHeadingForRoll to 90.
    }

    if (charPressed = "]") {
      set desiredCompassHeadingForRoll to 270.
      set lockedSteering to heading(270, 90, 0).
    }

    if (charPressed = "K") {
      set doTheClaw to not doTheClaw.
    }
  }
}

function setMaxEngineThrust {
  parameter eng.

  if (not eng:ignition or eng:thrustLimit < 100) {
    eng:activate().
    set eng:thrustLimit to 100.
  }
}

function calculateSteeringVectorAngle {
  parameter eng.
  parameter steerDir.

  if (steerDir = 0) {
    return 0.
  } else {
    return VANG(eng:facing:vector, steerDir:forevector).
  }
}

function shutdownEngine {
  parameter eng.

  if (eng:ignition) {
    // For some reason KSP (independent of KOS has a major problem with performance if a lof of engines have their thrustlimit set to 0)  This makes sure that this is not a performance problem.
    eng:shutdown().
    set eng:thrustlimit to 100.
  }
}

FUNCTION heading_of_vector { // heading_of_vector returns the heading of the vector (number range 0 to 360)
	PARAMETER vecT.

	LOCAL east IS VCRS(SHIP:UP:VECTOR, SHIP:NORTH:VECTOR).

	LOCAL trig_x IS VDOT(SHIP:NORTH:VECTOR, vecT).
	LOCAL trig_y IS VDOT(east, vecT).

	LOCAL result IS ARCTAN2(trig_y, trig_x).

	IF result < 0 {RETURN 360 + result.} ELSE {RETURN result.}
}

function compass_for {
  parameter ves is ship,thing is "default".

  declare local pointing is ves:facing:forevector.
  if not thing:istype("string") {
    set pointing to type_to_vector(ves,thing).
  }

  declare local east is east_for(ves).

  declare local trig_x is vdot(ves:north:vector, pointing).
  declare local trig_y is vdot(east, pointing).

  declare local result is arctan2(trig_y, trig_x).

  if result < 0 {
    return 360 + result.
  } else {
    return result.
  }
}

function east_for {
  parameter ves is ship.

  return vcrs(ves:up:vector, ves:north:vector).
}

function roll_for {
  parameter ves is ship,thing is "default".

  declare local pointing is ves:facing.
  if not thing:istype("string") {
    if thing:istype("vessel") or pointing:istype("part") {
      set pointing to thing:facing.
    } else if thing:istype("direction") {
      set pointing to thing.
    } else {
      print "type: " + thing:typename + " is not reconized by roll_for".
	}
  }

  declare local trig_x is vdot(pointing:topvector,ves:up:vector).
  if abs(trig_x) < 0.0035 {//this is the dead zone for roll when within 0.2 degrees of vertical
    return 0.
  } else {
    declare local vec_y is vcrs(ves:up:vector,ves:facing:forevector).
    declare local trig_y is vdot(pointing:topvector,vec_y).
    return arctan2(trig_y,trig_x).
  }
}

function vcompass {
    parameter input_vessel. //eg. ship
    parameter input_vector. // i.e. ship:velocity:surface (for prograde)
                            // or ship:facing:forevector (for facing vector rather  than vel vector).

    // What direction is up, north and east right now, as versor
    declare local up_versor to input_vessel:up:vector.
    declare local north_versor to input_vessel:north:vector.
    declare local east_versor to  vcrs(up_versor, north_versor).

    // east component of vector:
    declare local east_vel to vdot(input_vector, east_versor).

    // north component of vector:
    declare local north_vel to vdot(input_vector, north_versor).

    // inverse trig to take north and east components and make an angle:
    declare local compass to arctan2(east_vel, north_vel).

    // Note, compass is now in the range -180 to +180 (i.e. a heading of 270 is
    // expressed as -(90) instead.  This is entirely acceptable mathematically,
    // but if you want a number that looks like the navball compass, from 0 to 359.99,
    // you can do this to it:
    if compass < 0 {
        set compass to compass + 360.
    }

    return compass.
}

// How to draw a vetor
// set targetValArrow TO VECDRAW(
//   V(0,0,0),
//   heading(followTarget:Heading, 0):forevector * 10,
//   RGB(0,0,1),
//   "To target",
//   1.0,
//   TRUE,
//   0.2,
//   TRUE,
//   TRUE
// ).
