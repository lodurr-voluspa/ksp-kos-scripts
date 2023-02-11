@lazyglobal off.

// Released under the MIT license.  Use as you will but please give credit.

// Code for running fully walking quadrapedal rover in kerbal space program

// Fair warning, there is spaghetti, bugs, kludges, and, quite possibly, fudge factors.
// The documentation is also rubbish.  Just something fun I tossed together and uploaded
// because some folks are curious.  

core:part:getModule("kOSProcessor"):doEvent("Open Terminal").

declare local CONTROL_ROTATION_FACTOR to -90.

// Tweakables
local shoulderSwayAmount to 0.
local keyFrameTransitionSpeed to 0.
local servoDamping to 0.
local desiredFootHeight to 0.
local desiredFootLiftHeight to 0.
local torqueLimit to 0.
local rearLegOvertravel to 0.

local programComplete to false.

local shipMode to "wait".
local lrDirection to "S".
local speedMode to "W1".
local inReverse to false.
local walkStartup to false.
local presetPlanet to "kerbin".
local steerDir to 0.
local lastSteerHeading to 0.
local showArrows to true.
local vesselAtRest to false.

local hipLR_FL to 0.
local hipFB_FL to 0.
local knee_FL to 0.
local ankleLR_FL to 0.
local ankleFB_FL to 0.
local footpad_FL to 0.
local hipLR_FL_module to 0.
local hipFB_FL_module to 0.
local knee_FL_module to 0.
local ankleLR_FL_module to 0.
local ankleFB_FL_module to 0.
local shin_FL to 0.
local shoulder_FL to 0.

local hipLR_RL to 0.
local hipFB_RL to 0.
local knee_RL to 0.
local ankleLR_RL to 0.
local ankleFB_RL to 0.
local footpad_RL to 0.
local hipLR_RL_module to 0.
local hipFB_RL_module to 0.
local knee_RL_module to 0.
local ankleLR_RL_module to 0.
local ankleFB_RL_module to 0.
local shin_RL to 0.
local shoulder_RL to 0.

local hipLR_FR to 0.
local hipFB_FR to 0.
local knee_FR to 0.
local ankleLR_FR to 0.
local ankleFB_FR to 0.
local footpad_FR to 0.
local hipLR_FR_module to 0.
local hipFB_FR_module to 0.
local knee_FR_module to 0.
local ankleLR_FR_module to 0.
local ankleFB_FR_module to 0.
local shin_FR to 0.
local shoulder_FR to 0.

local hipLR_RR to 0.
local hipFB_RR to 0.
local knee_RR to 0.
local ankleLR_RR to 0.
local ankleFB_RR to 0.
local footpad_RR to 0.
local hipLR_RR_module to 0.
local hipFB_RR_module to 0.
local knee_RR_module to 0.
local ankleLR_RR_module to 0.
local ankleFB_RR_module to 0.
local shin_RR to 0.
local shoulder_RR to 0.

local reactor to 0.
local reactorModule to 0.

local keyframePercentage to 1.
local secondaryKeyFrame to 1.
local strideModifier to 0.

local a1 to 0.
local a2 to 0.
local a3 to 0.
local targetValArrow to 0.

local distancesHipToKnee to 0.
local distancesKneeToAnkle to 0.
local distancesAnkleToFoot to 0.

local legRecoveryMode to lexicon().
set legRecoveryMode["FL"] to 0.
set legRecoveryMode["RL"] to 0.
set legRecoveryMode["FR"] to 0.
set legRecoveryMode["RR"] to 0.

findParts().

local hipLR_FL_bounds to hipLR_FL:bounds.
local hipLR_FR_bounds to hipLR_FR:bounds.
local hipLR_RL_bounds to hipLR_RL:bounds.
local hipLR_RR_bounds to hipLR_RR:bounds.

local footpad_FL_bounds to footpad_FL:bounds.
local footpad_RL_bounds to footpad_RL:bounds.
local footpad_FR_bounds to footpad_FR:bounds.
local footpad_RR_bounds to footpad_RR:bounds.

local lastHipAngle to lexicon().
lastHipAngle:add("FL", 0).
lastHipAngle:add("RL", 0).
lastHipAngle:add("FR", 0).
lastHipAngle:add("RR", 0).

// Cache values
local shipFacing to 0.
local shipFacingForevector to 0.
local shipUpForevector to 0.
local shipBody to 0.

// Calculated globals
local relHipAltFL to 0.
local relHipAltFR to 0.
local relHipAltRL to 0.
local relHipAltRR to 0.
local absShoulderAngle_FL to 0.
local absShoulderAngle_RL to 0.
local frontToBackTerrainAngle to 0.
local footPad_FL_terrainHeight to 0.
local footPad_RL_terrainHeight to 0.
local footPad_FR_terrainHeight to 0.
local footPad_RR_terrainHeight to 0.
local footPad_FL_terrainHeightDiff to 0.
local footPad_RL_terrainHeightDiff to 0.
local footPad_FR_terrainHeightDiff to 0.
local footPad_RR_terrainHeightDiff to 0.

local presetsCache to lexicon().
setupPresetsCache().
setPresets().
setDamping().
setTorqueLimit().

until programComplete {
    updateCaches().
    handleInput().
    

    if (shipMode = "walk") {
        doWalking().
    } else if(shipMode = "walkStart") {
        doWalkStartup().
    } else if (shipMode = "stand") {
        doStand().
    } else if (shipMode = "lay") {
        doLay().
    } else if (shipMode = "test") {
        doTestMode().
    } else if (shipMode = "jump") {
        doJump().
    } else if (shipMode = "jumpTurn") {
        doJumpTurn().
    } else if (shipMode = "turnInPlace") {
        doTurnInPlace().
    }

    printControlData().

    wait 0.
}

clearVecDraws().

function doWalking {
    if (inReverse) {
        set keyframePercentage to keyframePercentage - keyFrameTransitionSpeed.

        if (keyframePercentage < 1) {
            set keyframePercentage to 100.
            set walkStartup to false.
        }
    } else {
        set keyframePercentage to keyframePercentage + keyFrameTransitionSpeed.

        if (keyframePercentage > 100) {
            set keyframePercentage to 1.
            set walkStartup to false.
        }
    }
    

    if (strideModifier < 1) {
        set strideModifier to min(1, strideModifier + .02).
    }

    calculateHipHeights().
    calculateShoulders().        
    calculateFootpadTerrain().

    // Start Turning
    local leftTurningModifier to 1.0 * strideModifier.
    local rightTurningModifier to 1.0 * strideModifier.

    if (steerDir <> 0) {
        local currentDirection to vxcl(ship:up:forevector, shipFacingForevector).
        local starboardComparisonVector to vxcl(ship:up:forevector, shipFacing:starvector).
        local vangToDesiredDir to vang(currentDirection, steerDir).
        local vangToStarboard to vang(starboardComparisonVector, steerDir).

        if (vangToDesiredDir > 2) {
            if (vangToStarboard < 90) {
                set rightTurningModifier to .4.
            } else {
                set leftTurningModifier to .4.
            }
        } else {
            set steerDir to 0.
            drawSteerDir().
        }
    }
    // End Turning    

    doLegControl("FL", keyframePercentage,                footpad_FL, hipFB_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL, footpad_FL_bounds, absShoulderAngle_FL, footPad_FL_terrainHeight, footPad_FL_terrainHeightDiff, leftTurningModifier).
    doLegControl("RL", mod(keyframePercentage + 25, 101), footpad_RL, hipFB_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL, footpad_RL_bounds, absShoulderAngle_RL, footPad_RL_terrainHeight, footPad_RL_terrainHeightDiff, leftTurningModifier).
    doLegControl("FR", mod(keyframePercentage + 50, 101), footpad_FR, hipFB_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR, footpad_FR_bounds, absShoulderAngle_FL, footPad_FR_terrainHeight, footPad_FR_terrainHeightDiff, rightTurningModifier).
    doLegControl("RR", mod(keyframePercentage + 75, 101), footpad_RR, hipFB_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR, footpad_RR_bounds, absShoulderAngle_RL, footPad_RR_terrainHeight, footPad_RR_terrainHeightDiff, rightTurningModifier).
}

function doJumpTurn {
    // Tweakables
    local jumpStartKeyFrame to 50.
    local jumpEndKeyFrame to 75.

    set keyframePercentage to keyframePercentage + 1.    

    if (keyframePercentage > 160) {
        set keyframePercentage to 1.
        set desiredFootHeight to 4.
        set keyframePercentage to 1.
        set shoulderSwayAmount to 0.
        set shipMode to "stand".
        set servoDamping to 200.
        setDamping().
        return.
    }

    local shoulderThrow to 15.
    local footKeyframe to 60.
    local rearFrameAdjust to 10.
    set desiredFootHeight to 3.
    if (keyframePercentage < 40) {
        hipLR_FL_module:setfield("target angle", -shoulderThrow).
        hipLR_RL_module:setfield("target angle", shoulderThrow).
        hipLR_FR_module:setfield("target angle", shoulderThrow).
        hipLR_RR_module:setfield("target angle", -shoulderThrow).
    } else if (keyframePercentage > jumpStartKeyFrame and keyframePercentage < jumpEndKeyFrame) {
        set shoulderThrow to 20.
        legJump("FL", hipFB_FL_module, hipLR_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL, -shoulderThrow).
        legJump("RL", hipFB_RL_module, hipLR_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL, shoulderThrow).
        legJump("FR", hipFB_FR_module, hipLR_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR, shoulderThrow).
        legJump("RR", hipFB_RR_module, hipLR_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR, -shoulderThrow).
        return.
    } else if (keyframePercentage >= jumpEndKeyFrame) {
        if (keyframePercentage = 100) {
            set servoDamping to 200.
            setDamping().
        }

        set shoulderThrow to -shoulderThrow.
        hipLR_FL_module:setfield("target angle", -shoulderThrow).
        hipLR_RL_module:setfield("target angle", shoulderThrow).
        hipLR_FR_module:setfield("target angle", shoulderThrow).
        hipLR_RR_module:setfield("target angle", -shoulderThrow).
        set desiredFootHeight to 2.5.
        set footKeyframe to 50.
    }

    calculateFootpadTerrain().

    doLegControl("FL", footKeyframe,                   footpad_FL, hipFB_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL, footpad_FL_bounds, -shoulderThrow, footPad_FL_terrainHeight, footPad_FL_terrainHeightDiff, 1).
    doLegControl("RL", footKeyframe + rearFrameAdjust, footpad_RL, hipFB_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL, footpad_RL_bounds, shoulderThrow, footPad_RL_terrainHeight, footPad_RL_terrainHeightDiff, 1).
    doLegControl("FR", footKeyframe,                   footpad_FR, hipFB_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR, footpad_FR_bounds, shoulderThrow, footPad_FR_terrainHeight, footPad_FR_terrainHeightDiff, 1).
    doLegControl("RR", footKeyframe + rearFrameAdjust, footpad_RR, hipFB_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR, footpad_RR_bounds, -shoulderThrow, footPad_RR_terrainHeight, footPad_RR_terrainHeightDiff, 1).
}

function doWalkStartup {
    local footKeyframe_FL to 0.
    local footKeyframe_RL to 0.
    local footKeyframe_FR to 0.
    local footKeyframe_RR to 0.

    if (inReverse) {
        set keyframePercentage to keyframePercentage - (keyFrameTransitionSpeed).

        if (keyframePercentage < 1) {
            set keyframePercentage to 1.
            set shipMode to "walk".
        }
    } else {
        set keyframePercentage to keyframePercentage + 1.5.

        if (keyframePercentage > 100) {
            set shipMode to "walk".
            set keyframePercentage to 1.
        }
    }

    calculateHipHeights().
    calculateShoulders().
    calculateFootpadTerrain().

    if (keyframePercentage < 12.5) {
        set footKeyframe_FL to 60.
        set footKeyframe_RL to 60.
        set footKeyframe_FR to 60.
        set footKeyframe_RR to 87.5.
    } else if (keyframePercentage <= 25) {
        set footKeyframe_FL to 60.
        set footKeyframe_RL to 60.
        set footKeyframe_FR to 60.
        set footKeyframe_RR to 75.
    } else if (keyframePercentage <= 37.5) {
        set footKeyframe_FL to 60.
        set footKeyframe_RL to 60.
        set footKeyframe_FR to 87.5.
        set footKeyframe_RR to 75.
    } else if (keyframePercentage <= 50) {
        set footKeyframe_FL to 60.
        set footKeyframe_RL to 60.
        set footKeyframe_FR to 51.
        set footKeyframe_RR to 75.
    } else if (keyframePercentage <= 62.5) {
        set footKeyframe_FL to 60.
        set footKeyframe_RL to 87.5.
        set footKeyframe_FR to 51.
        set footKeyframe_RR to 75.
    } else if (keyframePercentage <= 75) {
        set footKeyframe_FL to 60.
        set footKeyframe_RL to 26.
        set footKeyframe_FR to 51.
        set footKeyframe_RR to 75.
    } else if (keyframePercentage <= 87.5) {
        set footKeyframe_FL to 87.5.
        set footKeyframe_RL to 26.
        set footKeyframe_FR to 51.
        set footKeyframe_RR to 75.
    } else {
        set footKeyframe_FL to 1.
        set footKeyframe_RL to 26.
        set footKeyframe_FR to 51.
        set footKeyframe_RR to 75.
    }

    doLegControl("FL", footKeyframe_FL,  footpad_FL, hipFB_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL, footpad_FL_bounds, absShoulderAngle_FL, footPad_FL_terrainHeight, footPad_FL_terrainHeightDiff, 0.5).
    doLegControl("RL", footKeyframe_RL,  footpad_RL, hipFB_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL, footpad_RL_bounds, absShoulderAngle_RL, footPad_RL_terrainHeight, footPad_RL_terrainHeightDiff, 0.5).
    doLegControl("FR", footKeyframe_FR,  footpad_FR, hipFB_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR, footpad_FR_bounds, absShoulderAngle_FL, footPad_FR_terrainHeight, footPad_FR_terrainHeightDiff, 0.5).
    doLegControl("RR", footKeyframe_RR, footpad_RR, hipFB_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR, footpad_RR_bounds, absShoulderAngle_RL, footPad_RR_terrainHeight, footPad_RR_terrainHeightDiff, 0.5).
}

function doLegControl {
    parameter legName.
    parameter keyframePercentage.
    parameter footpad.
    parameter hipFB_module.
    parameter knee_module.
    parameter ankleFB_module.
    parameter ankleLR_module.
    parameter shin.
    parameter footBounds.
    parameter shoulderAngle.
    parameter footpadTerrainHeight.
    parameter terrainHeightDiff.
    parameter turningModifier.

    if (legRecoveryMode[legName] <> 0) {
        doStuckRearLegRecovery(legName, hipFB_module, knee_module).
        return.
    } else if (keyframePercentage > 75 and speedMode:startswith("B") and vang(shipFacingForevector, footpad:position) > 140) {
        set legRecoveryMode[legName] to "stuckBack".
        set lastHipAngle[legName] to 179.
    }

    set terrainHeightDiff to max(-.5, min(.5, terrainHeightDiff)).

    local distance_hipToKnee to distancesHipToKnee.
    local distance_kneeToAnkle to distancesKneeToAnkle.
    local footHeightFromGround to footBounds:bottomaltradar.

    local footLiftHeight to desiredFootLiftHeight.

    local desiredStrideHeight to desiredFootHeight - terrainHeightDiff.

    set desiredStrideHeight to min(4.8, desiredStrideHeight + abs(footHeightFromGround) - distancesAnkleToFoot).
    local shoulderAngleLengthDiff to 1 / (cos(shoulderAngle)).

    set desiredStrideHeight to desiredStrideHeight * shoulderAngleLengthDiff.

    local maxRearAngle to arcCos(min(.999, (desiredStrideHeight - distance_kneeToAnkle) / distance_hipToKnee)) * turningModifier.
    local maxForwardAngle to arcCos(min(.999, desiredStrideHeight / (distance_hipToKnee + distance_kneeToAnkle))) * turningModifier.
    local cycleAngleRange to (maxForwardAngle + maxRearAngle + rearLegOvertravel).

    local hipFB_angle to 0.
    local hipMotionPush to true.

    if (keyframePercentage <= 75) {
        // Forward walking motion angle set
        local maxForwardTravelDistance to sin(maxForwardAngle).
        local maxRearwardTravelDistance to sin(maxRearAngle).
        local cycleDistancePerKeyFrame to (maxForwardTravelDistance + maxRearwardTravelDistance) / 75.
        local keyFrameDistance to cycleDistancePerKeyFrame * keyframePercentage.
        if (keyFrameDistance <= maxForwardTravelDistance) {
            set hipFB_angle to arcSin(maxForwardTravelDistance - keyFrameDistance).
        } else {
            set hipFB_angle to -arcSin(keyFrameDistance - maxForwardTravelDistance).
        }

    } else {
        // Foot lift angle set
        local keyFrameRatio to ((keyframePercentage - 75) / 25).
        local rawHipAngle to cycleAngleRange - cycleAngleRange * keyFrameRatio.
        
        if (rawHipAngle <= maxForwardAngle) {
            set hipFB_angle to maxForwardAngle - rawHipAngle.
        } else {
            set hipFB_angle to -(rawHipAngle - maxForwardAngle).
        }

        set hipMotionPush to false.
    }

    //Re-angle legs for hills and startup
    if (legName:startsWith("R")) {
        local angleMod to -abs(frontToBackTerrainAngle).
        if (inReverse or walkStartup) {
            set angleMod to angleMod - 20. 
        }
        hipFB_module:setfield("target angle", hipFB_angle + angleMod).
    } else {
        local angleMod to abs(frontToBackTerrainAngle / 2).
        hipFB_module:setfield("target angle", hipFB_angle + angleMod).
    }

    // Tripping prevention
    if (not hipMotionPush and keyframePercentage > 95 and footHeightFromGround < 0) {
        set hipFB_angle to lastHipAngle[legName].
    }
    
    set lastHipAngle[legName] to hipFB_angle.

    if (not hipMotionPush) {
        if (hipFB_angle <= 0) {
            set desiredStrideHeight to desiredStrideHeight - footLiftHeight.
        } else if (hipFB_angle > 0) {
            local forwardMovementcompleteness to  min(1, .1 + (maxForwardAngle - hipFB_angle) / maxForwardAngle).

            if (keyframePercentage > 99) {
                set forwardMovementcompleteness to 0.
            } else if (speedMode:startswith("B")) {
                set forwardMovementcompleteness to 1.
            }
            set desiredStrideHeight to desiredStrideHeight - (footLiftHeight * forwardMovementcompleteness).
        }
    }
    

    local newKneeAngle to calculateKneeAngle(desiredStrideHeight, distance_kneeToAnkle, distance_hipToKnee, hipFB_angle).
    knee_module:setfield("target angle", newKneeAngle).

    local footpadFacing to footpad:facing.
    local shinFacing to shin:facing.
    local footForwardSampleVector to vectorExclude(shipUpForevector, footpadFacing:topvector) * .1.
    local footSidewaysSampleVector to vectorExclude(shipUpForevector, shinFacing:starvector) * .1.

    local footPad_terrainHeight_forward to shipBody:geoPositionof(footpad:position + footForwardSampleVector):terrainheight.
    local footPad_terrainHeight_side to shipBody:geoPositionof(footpad:position + footSidewaysSampleVector):terrainheight.
    local forwardSampleHeightDiff to footPad_terrainHeight_forward - footpadTerrainHeight.
    local sidewaysSampleHeightDiff to footPad_terrainHeight_side - footpadTerrainHeight.

    local forwardRawAnkleAngle to arctan(abs(forwardSampleHeightDiff / .1)).
    local sidewaysRawAnkleAngle to arctan(abs(sidewaysSampleHeightDiff / .1)).
    
    local shinFacingStarVector to shinFacing:starvector.
    local shinFacingForeVector to shinFacing:forevector.
    local footpadForevector to vectorExclude(shinFacingStarVector, shinFacingForeVector).
    local footpadVangToUp to vang(shipUpForevector, footpadForevector).
    local desiredAnkleAngle to -footpadVangToUp.
    if (forwardSampleHeightDiff > 0) {
        set desiredAnkleAngle to desiredAnkleAngle + forwardRawAnkleAngle.
    } else {
        set desiredAnkleAngle to desiredAnkleAngle - forwardRawAnkleAngle.
    }

    ankleFB_module:setfield("target angle", max(-65, desiredAnkleAngle)).

    local shinToUp to vang(shipUpForevector, vectorExclude(shinFacingForeVector, -shinFacingStarVector)) - 90.
    local desiredAnkleLRAngle to -shinToUp.
    if (sidewaysSampleHeightDiff > 0) {
        set desiredAnkleLRAngle to desiredAnkleLRAngle + sidewaysRawAnkleAngle.
    } else {
        set desiredAnkleLRAngle to desiredAnkleLRAngle - sidewaysRawAnkleAngle.
    }

    ankleLR_module:setfield("target angle", desiredAnkleLRAngle).
}

function doStuckRearLegRecovery {
    parameter legName.
    parameter hipFB_module.
    parameter knee_module.

    local hipAngle to lastHipAngle[legName].
    set hipAngle to hipAngle - 1.5.
    set lastHipAngle[legName] to hipAngle.

    print "-----hipAngle: " + hipAngle.

    knee_module:setfield("target angle", 134).
    hipFB_module:setfield("target angle", hipAngle).

    if (hipAngle < 95) {
        set legRecoveryMode[legName] to 0.
    }

}

function doStand {
    local footKeyframe_FL to 60.
    local footKeyframe_RL to 60.
    local footKeyframe_FR to 60.
    local footKeyframe_RR to 60.

    if (keyframePercentage <= 100) {
        set keyframePercentage to keyframePercentage + 2.

        local movingFootKeyframe to 83.5.

        if (mod(keyframePercentage, 25) > 12.5) {
            set movingFootKeyframe to 60.
        }

        if (keyframePercentage <= 25) {
            set footKeyframe_FL to movingFootKeyframe.
        } else if (keyframePercentage <= 50) {
            set footKeyframe_RR to movingFootKeyframe.
        } else if (keyframePercentage <= 75) {
            set footKeyframe_FR to movingFootKeyframe.
        } else {
            set footKeyframe_RL to movingFootKeyframe.
        }
    }

    calculateHipHeights().
    calculateShoulders().
    calculateFootpadTerrain().

    doLegControl("FL", footKeyframe_FL, footpad_FL, hipFB_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL, footpad_FL_bounds, absShoulderAngle_FL, footPad_FL_terrainHeight, footPad_FL_terrainHeightDiff, 1).
    doLegControl("RL", footKeyframe_RL, footpad_RL, hipFB_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL, footpad_RL_bounds, absShoulderAngle_RL, footPad_RL_terrainHeight, footPad_RL_terrainHeightDiff, 1).
    doLegControl("FR", footKeyframe_FR, footpad_FR, hipFB_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR, footpad_FR_bounds, absShoulderAngle_FL, footPad_FR_terrainHeight, footPad_FR_terrainHeightDiff, 1).
    doLegControl("RR", footKeyframe_RR, footpad_RR, hipFB_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR, footpad_RR_bounds, absShoulderAngle_RL, footPad_RR_terrainHeight, footPad_RR_terrainHeightDiff, 1).
}

function doLay {
    legLay("FL", hipFB_FL_module, hipLR_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL).
    legLay("RL", hipFB_RL_module, hipLR_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL).
    legLay("FR", hipFB_FR_module, hipLR_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR).
    legLay("RR", hipFB_RR_module, hipLR_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR).
}

function legLay {
    parameter legPosition.
    parameter hipFB_module.
    parameter hipLR_module.
    parameter knee_module.
    parameter ankleFB_module.
    parameter ankleLR_module.
    parameter shin.

    if (legPosition = "FL" or legPosition = "FR") {
        hipFB_module:setfield("target angle", -62).
        knee_module:setfield("target angle", 125).
        ankleFB_module:setfield("target angle", -65).
    } else {
        hipFB_module:setfield("target angle", -71).
        knee_module:setfield("target angle", 134).
        ankleFB_module:setfield("target angle", -64).
    }    

    hipLR_module:setfield("target angle", 0).    
    ankleLR_module:setfield("target angle", 0).    
    
    local footpadForevector to shin:facing:forevector.
    local footpadVangToUp to vang(shipUpForevector, footpadForevector).
    local desiredAnkleAngle to -footpadVangToUp.
    ankleFB_module:setfield("target angle", desiredAnkleAngle).
}


function doTurnInPlace {

    set keyframePercentage to keyframePercentage + 1.75.

    if (keyframePercentage > 60) {
        set keyframePercentage to 1.
        set walkStartup to false.
    } 

    calculateHipHeights().
    calculateFootpadTerrain().

    local legRLToFRKeyframe to 0.
    local legRRtoFLKeyFrame to 0.

    if (lrDirection = "L") {
        set legRLToFRKeyframe to 25.
    } else {
        set legRRtoFLKeyFrame to 25.
    }

    local shoulderAngleFL to calculateTurnKeyShoulderAngle(legRRtoFLKeyFrame, keyframePercentage).
    local shoulderAngleRL to -calculateTurnKeyShoulderAngle(legRLToFRKeyframe, keyframePercentage).
    local shoulderAngleFR to -calculateTurnKeyShoulderAngle(legRLToFRKeyframe, keyframePercentage).
    local shoulderAngleRR to calculateTurnKeyShoulderAngle(legRRtoFLKeyFrame, keyframePercentage).

    hipLR_FL_module:setfield("target angle", shoulderAngleFL).
    hipLR_RL_module:setfield("target angle", shoulderAngleRL).
    hipLR_FR_module:setfield("target angle", shoulderAngleFR).
    hipLR_RR_module:setfield("target angle", shoulderAngleRR).

    // keep the butt down
    set footPad_RL_terrainHeightDiff to footPad_RL_terrainHeightDiff + .15.
    set footPad_RR_terrainHeightDiff to footPad_RR_terrainHeightDiff + .15.

    doLegControl("FL", calculateTurnKeyFrame(legRRtoFLKeyFrame,  keyframePercentage, true), footpad_FL, hipFB_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL, footpad_FL_bounds, shoulderAngleFL, footPad_FL_terrainHeight, footPad_FL_terrainHeightDiff, 1).
    doLegControl("RL", calculateTurnKeyFrame(legRLToFRKeyframe, keyframePercentage, true),  footpad_RL, hipFB_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL, footpad_RL_bounds, shoulderAngleRL, footPad_RL_terrainHeight, footPad_RL_terrainHeightDiff, 1).
    doLegControl("FR", calculateTurnKeyFrame(legRLToFRKeyframe, keyframePercentage, false),  footpad_FR, hipFB_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR, footpad_FR_bounds, shoulderAngleFR, footPad_FR_terrainHeight, footPad_FR_terrainHeightDiff, 1).
    doLegControl("RR", calculateTurnKeyFrame(legRRtoFLKeyFrame,  keyframePercentage, false), footpad_RR, hipFB_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR, footpad_RR_bounds, shoulderAngleRR, footPad_RR_terrainHeight, footPad_RR_terrainHeightDiff, 1).
}

function calculateTurnKeyFrame {
    parameter keyFrameZone.
    parameter keyFrame.
    parameter leftsideLeg.

    local realKeyFrame to 60.
    local liftPushCutoverFrame to 12.5.

    if (keyframe > keyFrameZone and keyFrame <= keyFrameZone + 25) {
        set keyFrame to mod(keyFrame, 25) + 1.

        if (keyFrame < liftPushCutoverFrame) {
            set realKeyFrame to 83.5.
        } else {
            if (lrDirection = "L") {
                if (leftsideLeg) {
                    set realKeyFrame to 70.
                } else {
                    set realKeyFrame to 50.
                }
            } else {
                if (not leftsideLeg) {
                    set realKeyFrame to 70.
                } else {
                    set realKeyFrame to 50.
                }
            }
            
        }
    }

    return realKeyFrame.
}

function calculateTurnKeyShoulderAngle {
    parameter keyframeZone.
    parameter keyFrame.  

    local shoulderAngle to 0.  
    local angleTurnAmt to 25.

    if (keyframe > keyFrameZone and keyFrame <= keyFrameZone + 25) {
        if (lrDirection = "L") {
            set shoulderAngle to -angleTurnAmt.
        } else {
            set shoulderAngle to angleTurnAmt.    
        }
    } else if (keyframe > keyframeZone and keyFrame <=50) {
        local angleModifier to max(0, 1 - ((keyFrame - 25) / 25)).
        if (lrDirection = "L") {
            set shoulderAngle to -angleTurnAmt * angleModifier.
        } else {
            set shoulderAngle to angleTurnAmt * angleModifier.    
        }
    }

    return shoulderAngle.
}

function doJump {
    legJump("FL", hipFB_FL_module, hipLR_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL, 0).
    legJump("RL", hipFB_RL_module, hipLR_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL, 0).
    legJump("FR", hipFB_FR_module, hipLR_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR, 0).
    legJump("RR", hipFB_RR_module, hipLR_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR, 0).
}

function legJump {
    parameter legPosition.
    parameter hipFB_module.
    parameter hipLR_module.
    parameter knee_module.
    parameter ankleFB_module.
    parameter ankleLR_module.
    parameter shin.
    parameter shoulderAngle.

    if (legPosition = "FL" or legPosition = "FR") {
        hipFB_module:setfield("target angle", 0).
        knee_module:setfield("target angle", 0).
    } else {
        hipFB_module:setfield("target angle", 0).
        knee_module:setfield("target angle", 0).
    }    

    hipLR_module:setfield("target angle", shoulderAngle).    
    ankleLR_module:setfield("target angle", 0).
    ankleFB_module:setfield("target angle", 0).
    
    local footpadForevector to shin:facing:forevector.
    local footpadVangToUp to vang(shipUpForevector, footpadForevector).
    local desiredAnkleAngle to -footpadVangToUp.
    ankleFB_module:setfield("target angle", desiredAnkleAngle).
}

function calculateHipHeights {
    local hipAltFL to hipLR_FL_bounds:bottomAlt.
    local hipAltFR to hipLR_FR_bounds:bottomAlt.
    local hipAltRL to hipLR_RL_bounds:bottomAlt.
    local hipAltRR to hipLR_RR_bounds:bottomAlt.
    local lowestHipAlt to min(hipAltFL, min(hipAltFR, min(hipAltRL, hipAltRR))).
    set relHipAltFL to hipAltFL - lowestHipAlt.
    set relHipAltFR to hipAltFR - lowestHipAlt.
    set relHipAltRL to hipAltRL - lowestHipAlt.
    set relHipAltRR to hipAltRR - lowestHipAlt.


    set frontToBackTerrainAngle to 0.
}

function calculateShoulders {
    local shoulder_FL_facing to shoulder_FL:facing.
    local shoulder_RL_facing to shoulder_RL:facing.
    local shoulderAngle_FL to min(25, vang(shipUpForevector, vectorExclude(shoulder_FL_facing:topvector, shoulder_FL_facing:starvector))).
    local shoulderAngle_RL to min(25, vang(shipUpForevector, vectorExclude(shoulder_RL_facing:topvector, shoulder_RL_facing:starvector))).

    if (relHipAltFL < relHipAltFR) {
        set shoulderAngle_FL to -shoulderAngle_FL.
    }     

    if (relHipAltRL < relHipAltRR) {
        set shoulderAngle_RL to -shoulderAngle_RL.
    }

    local swayAmt to 0.
    if (keyframePercentage < 25) {
        set swayAmt to (25 - keyframePercentage) / 25 * shoulderSwayAmount.
    } else if (keyframePercentage > 75) {
        set swayAmt to (keyframePercentage - 75) / 25 * shoulderSwayAmount.
    } else if (keyframePercentage > 25 and keyframePercentage < 50) {
        set swayAmt to (keyframePercentage - 25) / 25 * -shoulderSwayAmount.
    } else {
        set swayAmt to (75 - keyframePercentage) / 25 * -shoulderSwayAmount.
    }

    // print "swayAmt: " + swayAmt.

    hipLR_FL_module:setfield("target angle", shoulderAngle_FL  + swayAmt).
    hipLR_FR_module:setfield("target angle", -shoulderAngle_FL - swayAmt).
    hipLR_RL_module:setfield("target angle", shoulderAngle_RL  + swayAmt).
    hipLR_RR_module:setfield("target angle", -shoulderAngle_RL - swayAmt).

    set absShoulderAngle_FL to abs(shoulderAngle_FL).
    set absShoulderAngle_RL to abs(shoulderAngle_RL).
    
}

function calculateFootpadTerrain {
    set footPad_FL_terrainHeight to shipBody:geoPositionof(footpad_FL:position):terrainheight.
    set footPad_RL_terrainHeight to shipBody:geoPositionof(footpad_RL:position):terrainheight.
    set footPad_FR_terrainHeight to shipBody:geoPositionof(footpad_FR:position):terrainheight.
    set footPad_RR_terrainHeight to shipBody:geoPositionof(footpad_RR:position):terrainheight.
    local averageTerrainHeight to (footPad_FL_terrainHeight + footPad_RL_terrainHeight + footPad_FR_terrainHeight + footPad_RR_terrainHeight) / 4.
    set footPad_FL_terrainHeightDiff to footPad_FL_terrainHeight - averageTerrainHeight.
    set footPad_RL_terrainHeightDiff to footPad_RL_terrainHeight - averageTerrainHeight.
    set footPad_FR_terrainHeightDiff to footPad_FR_terrainHeight - averageTerrainHeight.
    set footPad_RR_terrainHeightDiff to footPad_RR_terrainHeight - averageTerrainHeight.

    local averageFrontFootpadHeight to (footPad_FL_terrainHeight + footPad_FR_terrainHeight) / 2.
    local averageRearFootpadHeight to (footPad_RL_terrainHeight + footPad_RR_terrainHeight) / 2.
    local distanceBetweenHips to (shoulder_FL:position - shoulder_FR:position):mag.
    local frontToBackHeightDifference to averageFrontFootpadHeight - averageRearFootpadHeight.

    set frontToBackTerrainAngle to arctan(frontToBackHeightDifference / distanceBetweenHips).
}

function handleInput {
  if terminal:input:haschar {
    declare local charPressed to terminal:input:getchar().

    if (charPressed = "/") {
      set programComplete to true.
      unlock all.
      clearVecDraws().
    }  

    if (charPressed = "o") {
        set shipMode to "wait".        
    }

    if (charPressed = "y") {
        set keyframePercentage to 1.
        set shipMode to "turnInPlace".
        set lrDirection to "L".
        set shoulderSwayAmount to 0.
        set servoDamping to 85.
        set desiredFootHeight to 4.
        set desiredFootLiftHeight to 3.
        setDamping().
    }

    if (charPressed = "u") {
        set keyframePercentage to 1.
        set shipMode to "turnInPlace".
        set lrDirection to "R".
        set shoulderSwayAmount to 0.
        set servoDamping to 85.
        set desiredFootHeight to 4.
        set desiredFootLiftHeight to 3.
        setDamping().
    }

    if (charPressed = "q") {
        startStandMode().
    }

    if (charPressed = "l") {
        set shipMode to "lay".
        set servoDamping to 200.
        setDamping().
    }

    if (charPressed = "k") {
        set shipMode to "lay".
        set servoDamping to 200.
        setDamping().

        if (vesselAtRest) {
            radiators on.
            reactorModule:doAction("Start Reactor", true).
            ladders off.
            deployAntennas(false).
            set vesselAtRest to false.
        } else {
            radiators off.
            reactorModule:doAction("Stop Reactor", true).
            ladders on.
            deployAntennas(true).
            set vesselAtRest to true.
        }
        
    }

    if (charPressed = "t") {
        set shipMode to "test".
        set speedMode to "W1".
        setPresets().
    }

    if (charPressed = terminal:input:ENTER) {
      set shipMode to "jump".
      set servoDamping to 0.
      setDamping().
    }

    if (charPressed = "0") {
      set shipMode to "jumpTurn".
      set keyframePercentage to 1.
      set servoDamping to 0.
      setDamping().
    }

    if (charPressed = "+") {
        set desiredFootHeight to desiredFootHeight + .1.
    }

    if (charPressed = "-") {
        set desiredFootHeight to desiredFootHeight - .1.
    }

    if (charPressed = "9") {
        set shoulderSwayAmount to shoulderSwayAmount + .5.
    }

    if (charPressed = "8") {
        set shoulderSwayAmount to shoulderSwayAmount - .5.
    }

    if (charPressed = "6") {
        set keyFrameTransitionSpeed to keyFrameTransitionSpeed + .1.
    }

    if (charPressed = "5") {
        set keyFrameTransitionSpeed to keyFrameTransitionSpeed - .1.
    }

    if (charPressed = "3") {
        set servoDamping to servoDamping + 5.
        setDamping().
    }

    if (charPressed = "2") {
        set servoDamping to servoDamping - 5.
        setDamping().
    }

    if (charPressed = "]") {
        set torqueLimit to torqueLimit + 5.
        setTorqueLimit().
    }

    if (charPressed = "[") {
        set torqueLimit to torqueLimit - 5.
        setTorqueLimit().
    }

    if (charPressed = "7") {
        set desiredFootLiftHeight to desiredFootLiftHeight + .1.
    }

    if (charPressed = "4") {
        set desiredFootLiftHeight to desiredFootLiftHeight - .1.
    }

    if (charPressed = ".") {
        set distancesKneeToAnkle to distancesKneeToAnkle * 1.01.
    }

    if (charPressed = ",") {
        set distancesKneeToAnkle to distancesKneeToAnkle  / 1.01.
    }

    if (charPressed = "h") {
        set speedMode to "B1".
        setPresets().
    }

    if (charPressed = "v") {
        if (showArrows) {
            set showArrows to false.
            drawSteerDir().
        } else {
            set showArrows to true.
            drawSteerDir().
        }
    }

    if (charPressed = "W") {
        set steerDir to heading(0 + CONTROL_ROTATION_FACTOR, 0):forevector.
        set lastSteerHeading to 0.
        drawSteerDir().
    }

    if (charPressed = "D") {
        set steerDir to heading(90 + CONTROL_ROTATION_FACTOR, 0):forevector.
        set lastSteerHeading to 90.
        drawSteerDir().
    }

    if (charPressed = "S") {
        set steerDir to heading(180 + CONTROL_ROTATION_FACTOR, 0):forevector.
        set lastSteerHeading to 180.
        drawSteerDir().
    }

    if (charPressed = "A") {
        set steerDir to heading(270 + CONTROL_ROTATION_FACTOR, 0):forevector.
        set lastSteerHeading to 270.
        drawSteerDir().
    }

    if (charPressed = "x") {
        set steerDir to 0.
        set lastSteerHeading to 0.
        drawSteerDir().
    }

    if (charPressed = terminal:input:LEFTCURSORONE) {
        set lastSteerHeading to lastSteerHeading - 5.
        set steerDir to heading(lastSteerHeading + CONTROL_ROTATION_FACTOR, 0):forevector.
        drawSteerDir().
    }

    if (charPressed = terminal:input:RIGHTCURSORONE) {
        set lastSteerHeading to lastSteerHeading + 5.
        set steerDir to heading(lastSteerHeading + CONTROL_ROTATION_FACTOR, 0):forevector.
        drawSteerDir().
    }

    if (charPressed = terminal:input:UPCURSORONE) {
        if (inReverse) {
            set inReverse to false.
            startStandMode().
            return.
        }

        if (shipMode = "walk") {
            if (speedMode = "W1") {
                set speedMode to "W2".
            } else if (speedMode = "W2") {
                set speedMode to "W3".
            } else if (speedMode = "W3") {
                set speedMode to "W4".
            }  else if (speedMode = "W4") {
                set speedMode to "W5".
            } else {
                set speedMode to "W1".
            }

            setPresets().
        } else {
            // Begin walking
            set lrDirection to "S".
            radiators on.
            reactorModule:doAction("Start Reactor", true).
            set shipMode to "walkStart".
            set walkStartup to true.
            set strideModifier to 0.2.
            set keyframePercentage to 0.
            set speedMode to "W1".
            setPresets().
        }
      
    }

    if (charPressed = terminal:input:DOWNCURSORONE) {
        if (shipMode = "walk") {
            if (speedMode = "W5") {
                set speedMode to "W4".
            } else if (speedMode = "W4") {
                set speedMode to "W3".
            } else if (speedMode = "W3") {
                set speedMode to "W2".
            } else if (speedMode = "W2") {
                set speedMode to "W1".
            } else if (speedMode = "W1") {
                startStandMode().              
            }

            setPresets().
        } else if (shipMode = "stand") {
            set inReverse to true.
            radiators on.
            reactorModule:doAction("Start Reactor", true).
            set walkStartup to true.
            set shipMode to "walkStart".
            set strideModifier to 0.2.
            set keyframePercentage to 0.
            set speedMode to "R1".
            setPresets().
        }
    }
  }
}

function startStandMode {
    set speedMode to "W1".
    set desiredFootLiftHeight to 5.
    set keyframePercentage to 1.
    set shoulderSwayAmount to 0.
    set shipMode to "stand".
    set servoDamping to 85.
    setDamping().
}

function printControlData {
    clearscreen.

    print "shipMode: " + shipMode.
    print "speed: " + speedMode.
    print "KeyFrame: " + keyframePercentage.
    print "StrideModifier: " + strideModifier.
    print "lrDirection: " + lrDirection.
    print "desiredFootHeight: " + desiredFootHeight.
    print "shoulderSway: " + shoulderSwayAmount.
    print "keyframeSpeed: " + keyFrameTransitionSpeed.
    print "damping: " + servoDamping.
    print "torqueLimit: " + torqueLimit.
    print "desiredFootLiftHeight: " + desiredFootLiftHeight.
    print "rearLegOvertravel: " + rearLegOvertravel.


}

function drawSteerDir {
    if (showArrows and steerDir <> 0) {
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
    set hipLR_FL to ship:partstagged("hipLR_FL")[0].
    set hipFB_FL to ship:partstagged("hipFB_FL")[0].
    set knee_FL to ship:partstagged("knee_FL")[0].
    set ankleLR_FL to ship:partstagged("ankleLR_FL")[0].
    set ankleFB_FL to ship:partstagged("ankleFB_FL")[0].
    set footpad_FL to ship:partstagged("footpad_FL")[0].
    set shin_FL to ship:partstagged("shin_FL")[0].
    set shoulder_FL to ship:partstagged("shoulder_FL")[0].
    set hipLR_FL_module to hipLR_FL:getmodule("ModuleRoboticRotationServo").
    set hipFB_FL_module to hipFB_FL:getmodule("ModuleRoboticRotationServo").
    set knee_FL_module to knee_FL:getmodule("ModuleRoboticRotationServo").
    set ankleLR_FL_module to ankleLR_FL:getmodule("ModuleRoboticRotationServo").
    set ankleFB_FL_module to ankleFB_FL:getmodule("ModuleRoboticServoHinge").
    set distancesHipToKnee to (hipFB_FL:position - knee_FL:position):mag.
    set distancesKneeToAnkle to vectorexclude(knee_FL:facing:forevector, ankleFB_FL:position - knee_FL:position):mag.
    set distancesAnkleToFoot to (ankleFB_FL:position - footpad_FL:position):mag + (footpad_FL:bounds:size:z / 2).

    set hipLR_RL to ship:partstagged("hipLR_RL")[0].
    set hipFB_RL to ship:partstagged("hipFB_RL")[0].
    set knee_RL to ship:partstagged("knee_RL")[0].
    set ankleLR_RL to ship:partstagged("ankleLR_RL")[0].
    set ankleFB_RL to ship:partstagged("ankleFB_RL")[0].
    set footpad_RL to ship:partstagged("footpad_RL")[0].
    set shin_RL to ship:partstagged("shin_RL")[0].
    set shoulder_RL to ship:partstagged("shoulder_RL")[0].
    set hipLR_RL_module to hipLR_RL:getmodule("ModuleRoboticRotationServo").
    set hipFB_RL_module to hipFB_RL:getmodule("ModuleRoboticRotationServo").
    set knee_RL_module to knee_RL:getmodule("ModuleRoboticRotationServo").
    set ankleLR_RL_module to ankleLR_RL:getmodule("ModuleRoboticRotationServo").
    set ankleFB_RL_module to ankleFB_RL:getmodule("ModuleRoboticServoHinge").

    set hipLR_FR to ship:partstagged("hipLR_FR")[0].
    set hipFB_FR to ship:partstagged("hipFB_FR")[0].
    set knee_FR to ship:partstagged("knee_FR")[0].
    set ankleLR_FR to ship:partstagged("ankleLR_FR")[0].
    set ankleFB_FR to ship:partstagged("ankleFB_FR")[0].
    set footpad_FR to ship:partstagged("footpad_FR")[0].
    set shin_FR to ship:partstagged("shin_FR")[0].
    set shoulder_FR to ship:partstagged("shoulder_FR")[0].
    set hipLR_FR_module to hipLR_FR:getmodule("ModuleRoboticRotationServo").
    set hipFB_FR_module to hipFB_FR:getmodule("ModuleRoboticRotationServo").
    set knee_FR_module to knee_FR:getmodule("ModuleRoboticRotationServo").
    set ankleLR_FR_module to ankleLR_FR:getmodule("ModuleRoboticRotationServo").
    set ankleFB_FR_module to ankleFB_FR:getmodule("ModuleRoboticServoHinge").    

    set hipLR_RR to ship:partstagged("hipLR_RR")[0].
    set hipFB_RR to ship:partstagged("hipFB_RR")[0].
    set knee_RR to ship:partstagged("knee_RR")[0].
    set ankleLR_RR to ship:partstagged("ankleLR_RR")[0].
    set ankleFB_RR to ship:partstagged("ankleFB_RR")[0].
    set footpad_RR to ship:partstagged("footpad_RR")[0].
    set shin_RR to ship:partstagged("shin_RR")[0].
    set shoulder_RR to ship:partstagged("shoulder_RR")[0].
    set hipLR_RR_module to hipLR_RR:getmodule("ModuleRoboticRotationServo").
    set hipFB_RR_module to hipFB_RR:getmodule("ModuleRoboticRotationServo").
    set knee_RR_module to knee_RR:getmodule("ModuleRoboticRotationServo").
    set ankleLR_RR_module to ankleLR_RR:getmodule("ModuleRoboticRotationServo").
    set ankleFB_RR_module to ankleFB_RR:getmodule("ModuleRoboticServoHinge").    

    set reactor to ship:partsnamed("M2X.Reactor")[0].
    set reactorModule to reactor:getmodule("ModuleResourceConverter").

}

function setDamping {
    hipLR_FL_module:setfield("damping", servoDamping).
    hipFB_FL_module:setfield("damping", servoDamping).
    knee_FL_module:setfield("damping", servoDamping).
    ankleLR_FL_module:setfield("damping", servoDamping).
    ankleFB_FL_module:setfield("damping", servoDamping).

    hipLR_RL_module:setfield("damping", servoDamping).
    hipFB_RL_module:setfield("damping", servoDamping).
    knee_RL_module:setfield("damping", servoDamping).
    ankleLR_RL_module:setfield("damping", servoDamping).
    ankleFB_RL_module:setfield("damping", servoDamping).

    hipLR_FR_module:setfield("damping", servoDamping).
    hipFB_FR_module:setfield("damping", servoDamping).
    knee_FR_module:setfield("damping", servoDamping).
    ankleLR_FR_module:setfield("damping", servoDamping).
    ankleFB_FR_module:setfield("damping", servoDamping).

    hipLR_RR_module:setfield("damping", servoDamping).
    hipFB_RR_module:setfield("damping", servoDamping).
    knee_RR_module:setfield("damping", servoDamping).
    ankleLR_RR_module:setfield("damping", servoDamping).
    ankleFB_RR_module:setfield("damping", servoDamping).
}

function setTorqueLimit {
    local torqueKey to "torque limit(%)".
    hipLR_FL_module:setfield(torqueKey, torqueLimit).
    hipFB_FL_module:setfield(torqueKey, torqueLimit).
    knee_FL_module:setfield(torqueKey, torqueLimit).
    
    hipLR_RL_module:setfield(torqueKey, torqueLimit).
    hipFB_RL_module:setfield(torqueKey, torqueLimit).
    knee_RL_module:setfield(torqueKey, torqueLimit).
    
    hipLR_FR_module:setfield(torqueKey, torqueLimit).
    hipFB_FR_module:setfield(torqueKey, torqueLimit).
    knee_FR_module:setfield(torqueKey, torqueLimit).
    
    hipLR_RR_module:setfield(torqueKey, torqueLimit).
    hipFB_RR_module:setfield(torqueKey, torqueLimit).
    knee_RR_module:setfield(torqueKey, torqueLimit).
    
}

function updateCaches {
    set shipUpForevector to ship:up:forevector.
    set shipBody to ship:body.
    set shipFacing to ship:facing.
    set shipFacingForevector to shipFacing:forevector.
}

function magOfVecAAlongVecB {
  parameter a.
  parameter b.

  return vdot(a, b) / b:mag.
}

function doTestMode {
    local iterationFrames to 60.
    local shoulderSwayRange to 20.
    local baseLegHeight to 4.
    local legHeightRange to 1.

    set secondaryKeyFrame to secondaryKeyFrame + 1.
    if (secondaryKeyFrame > 8 * iterationFrames) {
        set secondaryKeyFrame to 1.
        startStandMode().
    }

    

    print "secondaryKeyFrame: " + secondaryKeyFrame.

    if (secondaryKeyFrame < iterationFrames) {
        local swayAmt to shoulderSwayRange * (secondaryKeyFrame / iterationFrames). 
        testModeShoulderSway(swayAmt, swayAmt, 0, 0, 3, 3, 3, 3).
    } else if (secondaryKeyFrame < 2 * iterationFrames) {
        local swayAmt to shoulderSwayRange * ((2 * iterationFrames - secondaryKeyFrame) / iterationFrames).
        testModeShoulderSway(swayAmt, swayAmt, 0, 0, 3, 3, 3, 3).
    } else if (secondaryKeyFrame < 3 * iterationFrames) {
        local swayAmt to -shoulderSwayRange * ((secondaryKeyFrame - 2 * iterationFrames) / iterationFrames).
        testModeShoulderSway(swayAmt, swayAmt, 0, 0, 3, 3, 3, 3).
    } else if (secondaryKeyFrame < 4 * iterationFrames) {
        local swayAmt to -shoulderSwayRange * ((4 * iterationFrames - secondaryKeyFrame) / iterationFrames).
        testModeShoulderSway(swayAmt, swayAmt, 0, 0, 3, 3, 3, 3).
    } 
    
    else if (secondaryKeyFrame < 5 * iterationFrames) {
        local legHeightMod to legHeightRange * ((secondaryKeyFrame - 4 * iterationFrames) / iterationFrames).
        local heightFront to baseLegHeight + legHeightMod.
        local heightRear to baseLegHeight - legHeightMod.
        testModeShoulderSway(0, 0, 0, 0, heightFront, heightRear, heightFront, heightRear).
    } else if (secondaryKeyFrame < 6 * iterationFrames) {
        local legHeightMod to legHeightRange * ((6 * iterationFrames - secondaryKeyFrame) / iterationFrames).
        local heightFront to baseLegHeight + legHeightMod.
        local heightRear to baseLegHeight - legHeightMod.
        testModeShoulderSway(0, 0, 0, 0, heightFront, heightRear, heightFront, heightRear).
    } else if (secondaryKeyFrame < 7 * iterationFrames) {
        local legHeightMod to legHeightRange * ((secondaryKeyFrame - 6 * iterationFrames) / iterationFrames).
        local heightFront to baseLegHeight - legHeightMod.
        local heightRear to baseLegHeight + legHeightMod.
        testModeShoulderSway(0, 0, 0, 0, heightFront, heightRear, heightFront, heightRear).
    } else if (secondaryKeyFrame < 8 * iterationFrames) {
        local legHeightMod to legHeightRange * ((8 * iterationFrames - secondaryKeyFrame) / iterationFrames).
        local heightFront to baseLegHeight - legHeightMod.
        local heightRear to baseLegHeight + legHeightMod.
        testModeShoulderSway(0, 0, 0, 0, heightFront, heightRear, heightFront, heightRear).
    } else {
        doStand().
    }
}

function testModeShoulderSway {
    parameter swayAmtFront.
    parameter swayAmtRear.
    parameter terrainDiffFront.
    parameter terrainDiffRight.
    parameter strideHeightFL.
    parameter strigeHeightRL.
    parameter strigeHeightFR.
    parameter strigeHeightRR.


    hipLR_FL_module:setfield("target angle", swayAmtFront).
    hipLR_RL_module:setfield("target angle", swayAmtRear).
    hipLR_FR_module:setfield("target angle", -swayAmtFront).
    hipLR_RR_module:setfield("target angle", -swayAmtRear).

    local footPad_FL_terrainHeight to shipBody:geoPositionof(footpad_FL:position):terrainheight.
    local footPad_RL_terrainHeight to shipBody:geoPositionof(footpad_RL:position):terrainheight.
    local footPad_FR_terrainHeight to shipBody:geoPositionof(footpad_FR:position):terrainheight.
    local footPad_RR_terrainHeight to shipBody:geoPositionof(footpad_RR:position):terrainheight.

    set desiredFootHeight to strideHeightFL.
    doLegControl("FL", 60, footpad_FL, hipFB_FL_module, knee_FL_module, ankleFB_FL_module, ankleLR_FL_module, shin_FL, footpad_FL_bounds, swayAmtFront, footPad_FL_terrainHeight, terrainDiffFront - terrainDiffRight, 1).
    set desiredFootHeight to strigeHeightRL.
    doLegControl("RL", 60, footpad_RL, hipFB_RL_module, knee_RL_module, ankleFB_RL_module, ankleLR_RL_module, shin_RL, footpad_RL_bounds, swayAmtRear, footPad_RL_terrainHeight, -terrainDiffFront - terrainDiffRight, 1).
    set desiredFootHeight to strigeHeightFR.
    doLegControl("FR", 60, footpad_FR, hipFB_FR_module, knee_FR_module, ankleFB_FR_module, ankleLR_FR_module, shin_FR, footpad_FR_bounds, -swayAmtFront, footPad_FR_terrainHeight, terrainDiffFront + terrainDiffRight, 1).
    set desiredFootHeight to strigeHeightRR.
    doLegControl("RR", 60, footpad_RR, hipFB_RR_module, knee_RR_module, ankleFB_RR_module, ankleLR_RR_module, shin_RR, footpad_RR_bounds, -swayAmtRear, footPad_RR_terrainHeight, -terrainDiffFront + terrainDiffRight, 1).
}

function setPresets {
    local presetGroup to presetsCache[speedMode][presetPlanet].
    set shoulderSwayAmount to presetGroup["SWAY"].
    set keyFrameTransitionSpeed to presetGroup["GAIT_SPEED"].
    set servoDamping to presetGroup["DAMPING"].
    set desiredFootHeight to presetGroup["STRIDE_H"].
    set desiredFootLiftHeight to presetGroup["FOOT_LIFT"].
    set torqueLimit to presetGroup["TORQUE"].
    set rearLegOvertravel to presetGroup["OVERTRAVEL"].

    setDamping().
}

function deployAntennas {
    parameter deploy.

    local antennaList to SHIP:MODULESNAMED("ModuleDeployableAntenna").
    local noseBayModule to ship:partsnamed(M2X.nosebay)[0]:getModule("ModuleAnimateGeneric").
    local serviceBayModule to ship:partsnamed(M2X.servicebay)[0]:getModule("ModuleAnimateGeneric").

    if (deploy) {
        if (noseBayModule:hasevent("open")) {
            noseBayModule:DOEVENT("open").
        }

        if (serviceBayModule:hasevent("open")) {
            serviceBayModule:DOEVENT("open").
        }

        FOR antenna IN antennaList { 
            if (antenna:hasevent("extend antenna")) {
                antenna:DOEVENT("extend antenna"). 
            }
        }
    } else {
        if (noseBayModule:hasevent("close")) {
            noseBayModule:DOEVENT("close").
        }

        if (serviceBayModule:hasevent("close")) {
            serviceBayModule:DOEVENT("close").
        }

        FOR antenna IN antennaList { 
            if (antenna:hasevent("retract antenna")) {
                antenna:DOEVENT("retract antenna"). 
            }
        }
    }
}

function setupPresetsCache {
    set presetsCache["W1"] to lexicon().
    set presetsCache["W2"] to lexicon().
    set presetsCache["W3"] to lexicon().
    set presetsCache["W4"] to lexicon().
    set presetsCache["W5"] to lexicon().
    set presetsCache["B1"] to lexicon().
    set presetsCache["R1"] to lexicon().

    set presetsCache["W1"]["kerbin"] to lexicon().
    local speed1KerbinPreset to presetsCache["W1"]["kerbin"].
    set speed1KerbinPreset["SWAY"] to 10.
    set speed1KerbinPreset["GAIT_SPEED"] to 2.1.
    set speed1KerbinPreset["DAMPING"] to 70.
    set speed1KerbinPreset["STRIDE_H"] to 4.5.
    set speed1KerbinPreset["FOOT_LIFT"] to 3.
    set speed1KerbinPreset["TORQUE"] to 100.
    set speed1KerbinPreset["OVERTRAVEL"] to 20.

    set presetsCache["W2"]["kerbin"] to lexicon().
    set speed1KerbinPreset to presetsCache["W2"]["kerbin"].
    set speed1KerbinPreset["SWAY"] to 10.
    set speed1KerbinPreset["GAIT_SPEED"] to 2.4.
    set speed1KerbinPreset["DAMPING"] to 70.
    set speed1KerbinPreset["STRIDE_H"] to 4.4.
    set speed1KerbinPreset["FOOT_LIFT"] to 3.
    set speed1KerbinPreset["TORQUE"] to 100.
    set speed1KerbinPreset["OVERTRAVEL"] to 20.

    set presetsCache["W3"]["kerbin"] to lexicon().
    set speed1KerbinPreset to presetsCache["W3"]["kerbin"].
    set speed1KerbinPreset["SWAY"] to 10.
    set speed1KerbinPreset["GAIT_SPEED"] to 3.2.
    set speed1KerbinPreset["DAMPING"] to 65.
    set speed1KerbinPreset["STRIDE_H"] to 4.4.
    set speed1KerbinPreset["FOOT_LIFT"] to 5.
    set speed1KerbinPreset["TORQUE"] to 100.
    set speed1KerbinPreset["OVERTRAVEL"] to 20.

    set presetsCache["W4"]["kerbin"] to lexicon().
    set speed1KerbinPreset to presetsCache["W4"]["kerbin"].
    set speed1KerbinPreset["SWAY"] to 10.
    set speed1KerbinPreset["GAIT_SPEED"] to 3.6.
    set speed1KerbinPreset["DAMPING"] to 45.
    set speed1KerbinPreset["STRIDE_H"] to 4.4.
    set speed1KerbinPreset["FOOT_LIFT"] to 5.2.
    set speed1KerbinPreset["TORQUE"] to 100.
    set speed1KerbinPreset["OVERTRAVEL"] to 20.

    set presetsCache["W5"]["kerbin"] to lexicon().
    set speed1KerbinPreset to presetsCache["W5"]["kerbin"].
    set speed1KerbinPreset["SWAY"] to 10.
    set speed1KerbinPreset["GAIT_SPEED"] to 4.7.
    set speed1KerbinPreset["DAMPING"] to 60.
    set speed1KerbinPreset["STRIDE_H"] to 4.5.
    set speed1KerbinPreset["FOOT_LIFT"] to 4.
    set speed1KerbinPreset["TORQUE"] to 100.
    set speed1KerbinPreset["OVERTRAVEL"] to 20.

    set presetsCache["B1"]["kerbin"] to lexicon().
    set speed1KerbinPreset to presetsCache["B1"]["kerbin"].
    set speed1KerbinPreset["SWAY"] to 10.
    set speed1KerbinPreset["GAIT_SPEED"] to 2.
    set speed1KerbinPreset["DAMPING"] to 80.
    set speed1KerbinPreset["STRIDE_H"] to 4.5.
    set speed1KerbinPreset["FOOT_LIFT"] to 4.5.
    set speed1KerbinPreset["TORQUE"] to 100.
    set speed1KerbinPreset["OVERTRAVEL"] to 35.

    set presetsCache["R1"]["kerbin"] to lexicon().
    local speed1KerbinPreset to presetsCache["R1"]["kerbin"].
    set speed1KerbinPreset["SWAY"] to 10.
    set speed1KerbinPreset["GAIT_SPEED"] to 2.1.
    set speed1KerbinPreset["DAMPING"] to 70.
    set speed1KerbinPreset["STRIDE_H"] to 4.5.
    set speed1KerbinPreset["FOOT_LIFT"] to 3.
    set speed1KerbinPreset["TORQUE"] to 100.
    set speed1KerbinPreset["OVERTRAVEL"] to 0.
}

function calculateKneeAngle {
    parameter dh.       // Desired stride height
    parameter ds.       // Distance knee to ankle (shin)
    parameter dt.       // Distance hip to knee (thigh)
    parameter hipAngle. // Current angle of hip

    local kneeAngle to false.

    if (hipAngle < 0) {
        local ah to -hipAngle.
        local d1 to dt * cos (ah).
        if (dh > d1) {
            local ak to arcsin(min(.9999, (dh - d1) / ds)).
            set kneeAngle to 90 - ak + ah.
        } else {
            local ak to arcsin(min(.9999, (d1 - dh) / ds)).
            set kneeAngle to ah + 90 + ak.
        }
    } else {
        local ah to hipAngle.
        local d1 to dt * cos (ah).
        if (dh > d1) {
            local ak to arcCos(min(.9999, (dh - d1) / ds)).
            set kneeAngle to ak - ah.
        } else {
            local ak to arcSin(min(.9999, (d1 - dh) / ds)).
            set kneeAngle to ak + 90 - ah.
        }
    }

    return kneeAngle.
}
