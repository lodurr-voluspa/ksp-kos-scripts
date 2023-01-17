// Released under the MIT license.  Use as you will but please give credit.

// Code for running a Tumbleweed rover which is a ball-rover driven by pistons in all directions.

// Fair warning, there is spaghetti, bugs, kludges, and, quite possibly, fudge factors.
// The documentation is also rubbish.  Just something fun I tossed together and uploaded
// because some folks are curious.  

@lazyglobal off.

declare local LEG_MAX_EXTENSION to 4.8.
declare local LEG_IMPACT_EXTENSION to 4.8.

declare local LEG_BASELINE_EXTENSION to 0.4.
declare local LEG_PUSH_EXTENSION to 3.0.
declare local LEG_BRAKE_EXTENSION to 2.8.

declare local LEG_BASELINE_EXTENSION_PRECISION to 0.4.
declare local LEG_PUSH_EXTENSION_PRECISION to 1.2.
declare local LEG_BRAKE_EXTENSION_PRECISION to 1.6.

declare local LEG_BASELINE_EXTENSION_CLEARANCE to 3.5.
declare local LEG_PUSH_EXTENSION_CLEARANCE to 4.8.
declare local LEG_BRAKE_EXTENSION_CLEARANCE to 4.8.

declare local LEG_BASELINE_EXTENSION_HILL to 0.
declare local LEG_PUSH_EXTENSION_HILL to 4.8.
declare local LEG_BRAKE_EXTENSION_HILL to 4.8.

declare local LEG_BASELINE_EXTENSION_TINY to 0.0.
declare local LEG_PUSH_EXTENSION_TINY to 0.9.
declare local LEG_BRAKE_EXTENSION_TINY to 1.5.

declare local LEG_BASELINE_EXTENSION_BOULDERING to 2.0.
declare local LEG_PUSH_EXTENSION_BOULDERING to 4.8.
declare local LEG_BRAKE_EXTENSION_BOULDERING to 4.8.

declare local LEG_BASELINE_EXTENSION_LOWG to 0.8.
declare local LEG_PUSH_EXTENSION_LOWG to LEG_MAX_EXTENSION.
declare local LEG_BRAKE_EXTENSION_LOWG to LEG_MAX_EXTENSION.

declare local legBaselineExtension to LEG_BASELINE_EXTENSION.
declare local legPushExtension to LEG_PUSH_EXTENSION.
declare local legBrakeExtension to LEG_BRAKE_EXTENSION.

declare local DAMPING_BRAKE_MODE to 100.
declare local DAMPING_PRECISION_MODE to 75.
declare local DAMPING_FULL_MODE to 120.
declare local DAMPING_DRIVE_MODE to 0.
declare local DAMPING_BOULDERING_MODE to 200.
// declare local DAMPING_DRIVE_MODE to 100.


declare local endProgram to false.

declare local steerDir to 0.                              // A heading that the craft wants to go towards
declare local lastSteerHeading to 0.
declare local shipMode to "wait".                        // ship mode to follow 'hover' allows for user control, 'land', 'launch', 'wait'
declare local driveMode to "fast".
declare local impactMode to true.
declare local impactModeCache to "drive". 
declare local CONTROL_ROTATION_FACTOR to -90.               // Rotates WASD controls from W pointing north -90 for VAB

declare local jumpTimer to 0.
declare local cachedJumpMode to 0.

declare local autoHillMode to true.
declare local autoHillModeEngaged to false.
declare local hillModeModeCache to "drive".

declare local spiderLegs to list().
declare local spiderLegsParts to list().
declare local spiderLegsCache to list().

declare local currentDamping to 0.

declare local targetValArrow to 0.
declare local unWantedVelocityArrow to 0.
declare local correctiveArrow to 0.

declare local bracingForImpact to false.

declare local showArrows to true.

core:part:getModule("kOSProcessor"):doEvent("Open Terminal").

findParts().
setLegExtensionParameters().

until endProgram = true {
    handleInput().
    printControlData().

    doLegs().

    wait 0.
}

clearVecDraws().

function doLegs {

    if (shipMode = "DRIVE") {
        declare local vangToDir to 0.
        declare local vangToUp to 0.
        declare local spiderLegPartForeVector to 0.

        declare local surfaceVelocity to ship:velocity:surface.
        declare local surfaceVelocityMag to surfaceVelocity:mag.
        declare local currentVelocity to vectorExclude(ship:up:forevector, surfaceVelocity).
        declare local currentVelocityMagnitude to currentVelocity:mag.
        declare local vangVelocityToSteering to vang(currentVelocity, steerDir).

        declare local angularMomentumMag to ship:angularmomentum:mag.

        declare local hillDetect to false.
        declare local readAheadPosition to steerDir:normalized * 6 + ship:position.
        declare local readAheadTerrainHeight to ship:body:geoPositionof(readAheadPosition):terrainheight.
        declare local readAheadPosition2 to steerDir:normalized * 8 + ship:position.
        declare local readAheadTerrainHeight2 to ship:body:geoPositionof(readAheadPosition2):terrainheight.
        declare local shipTerrainHeight to ship:geoposition:terrainheight.
        declare local terrainDiff to readAheadTerrainHeight - shipTerrainHeight.
        declare local terrainDiff2 to readAheadTerrainHeight2 - shipTerrainHeight.

        declare local driveMode_hill to driveMode = "hill".
        declare local driveMode_lowg to driveMode = "lowg".
        declare local driveMode_clearance to driveMode = "clearance".
        declare local driveMode_bouldering to driveMode = "bouldering".
        declare local driveMode_precision to driveMode = "precision".

        if ((terrainDiff > 2 and terrainDiff2 > 2.7) or (terrainDiff > 1.5 and terrainDiff2 > 2 and autoHillModeEngaged )) {  //Prevent oscillation of hill mode
            set hillDetect to true.
        }

        if (hillDetect and autoHillMode and not bracingForImpact and surfaceVelocityMag < 9) {
            if (not autoHillModeEngaged) {
                set autoHillModeEngaged to true.
                // if (driveMode <> "hill") {
                if (not driveMode_hill) {
                    set hillModeModeCache to driveMode.
                }                
                set driveMode to "hill".
                setLegExtensionParameters().
            }
        } else if (autoHillModeEngaged) {
            set autoHillModeEngaged to false.
            set driveMode to hillModeModeCache.
            setLegExtensionParameters().
        }

        // Prevents oscilliation of bracing maneuver near the cutoff point.
        if (bracingForImpact) {
            if (surfaceVelocityMag < 18) {
                set bracingForImpact to false.
                set driveMode to impactModeCache.
                setLegExtensionParameters().
            }
        } else if (impactMode and surfaceVelocityMag > 21) {
            if (not driveMode_clearance) {
            // if (driveMode <> "clearance") {

                set impactModeCache to driveMode.
            }
            set bracingForImpact to true.
            set driveMode to "clearance".
            setLegExtensionParameters().
        }


        declare local maxHeightOfPush to 5.5.
        if (driveMode_clearance) {
            set maxHeightOfPush to 11.
        } else if (driveMode_lowg) {
            set maxHeightOfPush to 6.
        } else if (driveMode_bouldering) {
            set maxHeightOfPush to 9.
        } else if (driveMode_hill) {
            set maxHeightOfPush to 10.
        }

        if (alt:radar > maxHeightOfPush
            or (vangVelocityToSteering < 10 and angularMomentumMag > 1200) 
            or (driveMode_precision and surfaceVelocityMag > 5 and vangVelocityToSteering < 15)
            or (vangVelocityToSteering < 20 and driveMode_bouldering and surfaceVelocityMag > 6)) {
            doDormant().
            return.
        }

        declare local invertedSteerDir to -steerDir.
        declare local shipUpVector to ship:up:forevector.
        declare local spiderLegsLength to spiderLegs:length.
        declare local spiderLegVectorExcluded to 0.

        declare local correctiveDirection to steerDir:normalized - currentVelocity:normalized.

        // if (showArrows) {
        //     set unWantedVelocityArrow TO VECDRAW(V(0,0,0), currentVelocity * 10, RGB(1,0,0), "ShedVel", 1.0, TRUE, 0.2, TRUE, TRUE).
        //     set correctiveArrow TO VECDRAW(V(0,0,0), correctiveDirection:normalized * 20, RGB(0,1,0), "Corrective", 1.0, TRUE, 0.2, TRUE, TRUE).
        // }

        // If not heading in the right direction adjust the steer direction to compensate.
        if (vangVelocityToSteering > 5 and currentVelocityMagnitude > 10) {
            set invertedSteerDir to -correctiveDirection.
        }

        // Start off with shorter strokes then pick up steam
        declare local velocityModifiedLegPushAmt to legPushExtension.
        if (not driveMode_lowg and not driveMode_hill and not driveMode_bouldering) {
        // if (driveMode <> "lowg" and driveMode <> "hill" and driveMode <> "bouldering") {

            declare local minimumPushAmount to legBaselineExtension + 1.
            declare local velocityModifier to min(15, surfaceVelocityMag) / 15.
            declare local pushRange to legPushExtension - minimumPushAmount.
            declare local desiredPushAmount to (velocityModifier * pushRange) + minimumPushAmount.
            set velocityModifiedLegPushAmt to max(minimumPushAmount, desiredPushAmount).

            // print "minimumPushAmount            " + minimumPushAmount.
            // print "velocityModifier:            " + velocityModifier.
            // print "pushRange:                   " + pushRange.
            // print "desiredPushAmount:           " + desiredPushAmount.
            // print "velocityModifiedLegPushAmt:  " + velocityModifiedLegPushAmt.
        }

        // Preload allows for starting the push stroke BEFORE it is in position to give it more time to push
        declare local preload to false.
        declare local preloadThreshold to 170.
        // print "angularMomentumMag: " + angularMomentumMag.
        if (angularMomentumMag > 500) {
            set preload to true.
            if (driveMode_lowg or driveMode_hill) {
                set preloadThreshold to max(130, 170 - ((angularMomentumMag - 500) / 14)).
                // print "preloadThreshold: " + preloadThreshold.
            }
            // print "preloadThreshold: " + preloadThreshold.
        }
        // print "preload: " + preload.

        FROM {local x is 0.} UNTIL x = spiderLegsLength STEP {set x to x + 1.} DO {
            set spiderLegPartForeVector to spiderLegsParts[x]:facing:forevector.                          
            set vangToUp to vang(spiderLegPartForeVector, shipUpVector).

            if (vangToUp > 125) {
                set spiderLegVectorExcluded to vectorExclude(shipUpVector, spiderLegPartForeVector).  
                set vangToDir to vang(spiderLegVectorExcluded, invertedSteerDir).

                // if (vangToDir < 90 or (preload and vangToUp > 170)) {
                if (vangToDir < 90 or (preload and vangToUp > preloadThreshold)) {
                    if (spiderLegsCache[x] <>                       velocityModifiedLegPushAmt) {
                        spiderLegs[x]:setfield("target extension",  velocityModifiedLegPushAmt).
                        set spiderLegsCache[x] to                   velocityModifiedLegPushAmt.
                    }
                } else {
                    if (spiderLegsCache[x] <>                       legBaselineExtension) {
                        spiderLegs[x]:setfield("target extension",  legBaselineExtension).
                        set spiderLegsCache[x] to                   legBaselineExtension.
                    }
                }
            } else {
                if (spiderLegsCache[x] <>                       legBaselineExtension) {
                    spiderLegs[x]:setfield("target extension",  legBaselineExtension).
                    set spiderLegsCache[x] to                   legBaselineExtension.
                }
            }
        }


    } else if (shipMode = "BRAKE") {
        doBrakeManeuver().
    } else if (shipMode = "JUMP") {
        doJumpManeuver().
    } else if (shipMode = "IMPACT") {
        doImpactManeuver().
    } else {
        for aLeg in spiderLegs {
            aLeg:setfield("target extension", 0).
        }  
    }
}

// Just hanging out.
function doDormant {
    declare local spiderLegsLength to spiderLegs:length.

    FROM {local x is 0.} UNTIL x = spiderLegsLength STEP {set x to x + 1.} DO {
        if (spiderLegsCache[x] <>                       legBaselineExtension) {
            spiderLegs[x]:setfield("target extension",  legBaselineExtension).
            set spiderLegsCache[x] to                   legBaselineExtension.
        }
    }
}

function doImpactManeuver {
    declare local spiderLegsLength to spiderLegs:length.

    FROM {local x is 0.} UNTIL x = spiderLegsLength STEP {set x to x + 1.} DO {
        if (spiderLegsCache[x] <>                       LEG_IMPACT_EXTENSION) {
            spiderLegs[x]:setfield("target extension",  LEG_IMPACT_EXTENSION).
            set spiderLegsCache[x] to                   LEG_IMPACT_EXTENSION.
        }
    }
}

function doJumpManeuver {
    declare local elapsedJumpTime to time:seconds - jumpTimer.

    if (elapsedJumpTime > 5.5 or (elapsedJumpTime > 1 and alt:radar < 3.8)) {
        set shipMode to cachedJumpMode.
    } else {
        declare local spiderLegsLength to spiderLegs:length.
        declare local spiderLegPartForeVector to 0.
        declare local vangToUp to 0.
        declare local shipUpVector to ship:up:forevector.
        declare local shockExtension to legBaselineExtension * 3.

        FROM {local x is 0.} UNTIL x = spiderLegsLength STEP {set x to x + 1.} DO {
            set spiderLegPartForeVector to spiderLegsParts[x]:facing:forevector.
            set vangToUp to vang(shipUpVector, spiderLegPartForeVector).

            if (vangToUp > 100) {
                if (elapsedJumpTime < 0.6) {
                    if (spiderLegsCache[x] <>                       LEG_MAX_EXTENSION) {
                        spiderLegs[x]:setfield("target extension",  LEG_MAX_EXTENSION).
                        set spiderLegsCache[x] to                   LEG_MAX_EXTENSION.
                    }
                } else {
                    if (spiderLegsCache[x] <>                       shockExtension) {
                        spiderLegs[x]:setfield("target extension",  shockExtension).
                        set spiderLegsCache[x] to                   shockExtension.
                    }
                }                
            } else {
                if (spiderLegsCache[x] <>                       legBaselineExtension) {
                    spiderLegs[x]:setfield("target extension",  legBaselineExtension).
                    set spiderLegsCache[x] to                   legBaselineExtension.
                }
            }
            
        }
    }
}

function doBraceManeuver {
    declare local vangToUp to 0.
    declare local spiderLegsLength to spiderLegs:length.
    declare local shipUpVector to ship:up:forevector.

    declare local legPosition to 0.
    declare local roverTerrainHeight to ship:geoposition:terrainheight.
    declare local roverPosition to ship:position.
    declare local legTerrainHeight to 0.
    declare local spiderLegForevector to 0.
    declare local modifiedLegExtension to 0.

    // Plant a wide base
    FROM {local x is 0.} UNTIL x = spiderLegsLength STEP {set x to x + 1.} DO {
        set spiderLegForevector to spiderLegsParts[x]:facing:forevector.
        set vangToUp to vang(spiderLegForevector, shipUpVector).

        // if (vangToUp > 120 and vangToUp < 150) {
        if (vangToUp > 140 and vangToUp < 170) {
            set legPosition to roverPosition + (spiderLegForevector * 6).
            set legTerrainHeight to ship:body:geoPositionof(legPosition):terrainheight.

            set modifiedLegExtension to max(-2.4, min(4.8, (roverTerrainHeight - legTerrainHeight))) + 1.
            setLeg(x, modifiedLegExtension).
         
        } else {
            // setLeg(x, legBaselineExtension).
            if (spiderLegsCache[x] <>                       legBaselineExtension) {
                spiderLegs[x]:setfield("target extension",  legBaselineExtension).
                set spiderLegsCache[x] to                   legBaselineExtension.
            }
        }
    }
}

function doBrakeManeuver {
    declare local directionOfVelocity to ship:velocity:surface.
    declare local relativeGroundVelocity to vectorExclude(ship:up:forevector, directionOfVelocity).
    declare local shipUpVector to ship:up:forevector.
    declare local spiderLegsLength to spiderLegs:length.
    declare local groundHeight to alt:radar.
    declare local vangToDir to 0.
    declare local vangToUp to 0.
    declare local spiderLegPartForeVector to 0.
    declare local spiderLegVectorExcluded to 0.

    if relativeGroundVelocity:mag > 3.5 and groundHeight < 7 {

        FROM {local x is 0.} UNTIL x = spiderLegsLength STEP {set x to x + 1.} DO {
            set spiderLegPartForeVector to spiderLegsParts[x]:facing:forevector.
            set vangToUp to vang(spiderLegPartForeVector, shipUpVector).

            if (vangToUp > 90 and vangToUp < 130) {
            // if (vangToUp < 140) {
                set spiderLegVectorExcluded to vectorExclude(shipUpVector, spiderLegPartForeVector).
                set vangToDir to vang(spiderLegVectorExcluded, relativeGroundVelocity).

                if (vangToDir < 60) {
                    if (spiderLegsCache[x] <>                       legBrakeExtension) {
                        spiderLegs[x]:setfield("target extension",  legBrakeExtension).
                        set spiderLegsCache[x] to                   legBrakeExtension.
                    }
                } else {
                    if (spiderLegsCache[x] <>                       legBaselineExtension) {
                        spiderLegs[x]:setfield("target extension",  legBaselineExtension).
                        set spiderLegsCache[x] to                   legBaselineExtension.
                    }
                }
            } else {
                if (spiderLegsCache[x] <>                       legBaselineExtension) {
                    spiderLegs[x]:setfield("target extension",  legBaselineExtension).
                    set spiderLegsCache[x] to                   legBaselineExtension.
                }
            }

        }

    } else if groundHeight > 12 {
        doDormant().
    } else {
        doBraceManeuver().
    }
}

function setLeg {
    parameter legId.
    parameter legVal.

    if (spiderLegsCache[legId] <> legVal) {
        spiderLegs[legId]:setfield("target extension", legVal).
        set spiderLegsCache[legId] to legVal.
    }
}

function setLegExtensionParameters {
    if (driveMode = "hill") {
        set legBaselineExtension to LEG_BASELINE_EXTENSION_HILL.
        set legPushExtension to LEG_PUSH_EXTENSION_HILL.
        set legBrakeExtension to LEG_BRAKE_EXTENSION_HILL. 
    } else if (driveMode = "precision") {
        set legBaselineExtension to LEG_BASELINE_EXTENSION_PRECISION.
        set legPushExtension to LEG_PUSH_EXTENSION_PRECISION.
        set legBrakeExtension to LEG_BRAKE_EXTENSION_PRECISION.  
    } else if (driveMode = "clearance") {
        set legBaselineExtension to LEG_BASELINE_EXTENSION_CLEARANCE.
        set legPushExtension to LEG_PUSH_EXTENSION_CLEARANCE.
        set legBrakeExtension to LEG_BRAKE_EXTENSION_CLEARANCE.  
    } else if (driveMode = "tiny") {
        set legBaselineExtension to LEG_BASELINE_EXTENSION_TINY.
        set legPushExtension to LEG_PUSH_EXTENSION_TINY.
        set legBrakeExtension to LEG_BRAKE_EXTENSION_TINY.  
    } else if (driveMode = "lowg") {
        set legBaselineExtension to LEG_BASELINE_EXTENSION_LOWG.
        set legPushExtension to LEG_PUSH_EXTENSION_LOWG.
        set legBrakeExtension to LEG_BRAKE_EXTENSION_LOWG.  
    } else if (driveMode = "bouldering") {
        set legBaselineExtension to LEG_BASELINE_EXTENSION_BOULDERING.
        set legPushExtension to LEG_PUSH_EXTENSION_BOULDERING.
        set legBrakeExtension to LEG_BRAKE_EXTENSION_BOULDERING.  
    } else {
        set legBaselineExtension to LEG_BASELINE_EXTENSION.
        set legPushExtension to LEG_PUSH_EXTENSION.
        set legBrakeExtension to LEG_BRAKE_EXTENSION.  
    }      
}

function printControlData {
    clearscreen.


    print "---Control Mode---".
    print "  Mode:                 " + shipMode.
    print "  DriveMode:            " + driveMode.
    print "  ImpactMode:           " + impactMode.
    print "  AutoHillMode:         " + autoHillMode.
    // print "  Steer:                " + steerDir.
    print "  Damping:              " + currentDamping.
    print "  Height:               " + alt:radar.
    print "  AngMom:               " + ship:angularmomentum:mag.

  
}

function handleInput {
  if terminal:input:haschar {

    declare local charPressed to terminal:input:getchar().

    if (charPressed = "/") {
      set endProgram to true.
      unlock all.
      for aLeg in spiderLegs {
        aLeg:setfield("target extension", 0).
      }      
    }

    if (charPressed = "W") {
        set steerDir to 0.
        set shipMode to "wait".
        setDampingRate(DAMPING_BRAKE_MODE).
    }

    if (charPressed = "B") {
        set steerDir to 0.
        set shipMode to "brake".
        set autoHillModeEngaged to false.
        setDampingRate(DAMPING_BRAKE_MODE).
    }

    if (charPressed = "f") {
        set driveMode to "fast".
        set autoHillModeEngaged to false.
        setLegExtensionParameters().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = "p") {
        set driveMode to "precision".
        set autoHillModeEngaged to false.
        setLegExtensionParameters().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = "c") {
        set driveMode to "clearance".
        set autoHillModeEngaged to false.
        setLegExtensionParameters().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = "h") {
        set driveMode to "hill".
        set autoHillModeEngaged to false.
        setLegExtensionParameters().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = "t") {
        set driveMode to "tiny".
        set autoHillModeEngaged to false.
        setLegExtensionParameters().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = "u") {
        set driveMode to "bouldering".
        set autoHillModeEngaged to false.
        setLegExtensionParameters().
        setDampingRate(DAMPING_BOULDERING_MODE).
    }

    if (charPressed = "l") {
        set driveMode to "lowg".
        set autoHillModeEngaged to false.
        setLegExtensionParameters().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = "i") {
        if (impactMode) {
            set impactMode to false.
        } else {
            set impactMode to true.
        }
    }

    if (charPressed = "o") {
        if (autoHillMode) {
            set autoHillMode to false.
        } else {
            set autoHillMode to true.
        }
    }

    if (charPressed = "m") {
        set shipMode to "impact".
        set autoHillModeEngaged to false.
        setLegExtensionParameters().
        setDampingRate(DAMPING_FULL_MODE).
    }

    if (charPressed = "a") {
        if (showArrows) {
            set showArrows to false.
            drawSteerDir().
        } else {
            set showArrows to true.
            drawSteerDir().
        }
    }

    if (charPressed = terminal:input:ENTER) {
        if (shipMode <> "jump") {
            set cachedJumpMode to shipMode.
        }        
        set shipMode to "jump".
        set jumpTimer to time:seconds.
    }

    if (charPressed = terminal:input:UPCURSORONE) {
        set shipMode to "drive".  
        set steerDir to heading(0 + CONTROL_ROTATION_FACTOR, 0):forevector.
        set lastSteerHeading to 0.
        drawSteerDir().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = terminal:input:RIGHTCURSORONE) {
        set shipMode to "drive".
        set steerDir to heading(90 + CONTROL_ROTATION_FACTOR, 0):forevector.
        set lastSteerHeading to 90.
        drawSteerDir().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = terminal:input:DOWNCURSORONE) {
        set shipMode to "drive".
        set steerDir to heading(180 + CONTROL_ROTATION_FACTOR, 0):forevector.
        set lastSteerHeading to 180.
        drawSteerDir().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = terminal:input:LEFTCURSORONE) {
        set shipMode to "drive".
        set steerDir to heading(270 + CONTROL_ROTATION_FACTOR, 0):forevector.
        set lastSteerHeading to 270.
        drawSteerDir().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = "7") {
        set shipMode to "drive".
        set lastSteerHeading to lastSteerHeading - 5.
        set steerDir to heading(lastSteerHeading + CONTROL_ROTATION_FACTOR, 0):forevector.
        drawSteerDir().
        setDampingRate(DAMPING_DRIVE_MODE).
    }

    if (charPressed = "9") {
        set shipMode to "drive".
        set lastSteerHeading to lastSteerHeading + 5.
        set steerDir to heading(lastSteerHeading + CONTROL_ROTATION_FACTOR, 0):forevector.
        drawSteerDir().
        setDampingRate(DAMPING_DRIVE_MODE).
    }
  }
}

function drawSteerDir {
    if (showArrows) {
        set targetValArrow TO VECDRAW(
        V(0,0,0),
        steerDir * 40,
        RGB(0,0,1),
        "Go",
        1.0,
        TRUE,
        0.2,
        TRUE,
        TRUE
        ).
    } else if (targetValArrow <> 0) {
        set targetValArrow to false.
        set targetValArrow to 0.
    }
}

function findParts {
    declare local spiderLegParts to ship:partsnamed("piston.03").

    for aLeg in spiderLegParts {
        declare local aLegMod to aLeg:getmodule("ModuleRoboticServoPiston").
        aLegMod:setfield("traverse rate", 20).
        aLegMod:setfield("damping", DAMPING_DRIVE_MODE).
        spiderLegsParts:add(aLeg).
        spiderLegs:add(aLegMod).
        spiderLegsCache:add(0).
    }
}

function setDampingRate {
    parameter newRate. // 0 - 200 range

    if (newRate = DAMPING_DRIVE_MODE and (driveMode = "precision" or driveMode = "tiny")) {
        set newRate to DAMPING_PRECISION_MODE.
    } else if (newRate = DAMPING_BRAKE_MODE and (driveMode = "lowg" or driveMode = "bouldering")) {
        set newRate to DAMPING_FULL_MODE.
    } else if (newRate = DAMPING_DRIVE_MODE and driveMode = "bouldering") {
        set newRate to DAMPING_BOULDERING_MODE.
    }

    if (newRate = currentDamping) {
        return.
    }

    for aLeg in spiderLegs {
        aLeg:setfield("damping", newRate).
    }

    set currentDamping to newRate.
}
