@lazyGlobal off.

local KERBAL_TARGET_NAME is "Bob Kerman".

local shipMode is "WAIT".
local shipModeRef is doWait@.
local endProgram is false.
local showArrows is false.

local timer is 0.
local iterator is 0.
local waveDistance is 0.

local kerbalTarget is 0.

local pistons is list().

findParts().
clearBoard().

// Open terminal window automatically
core:part:getModule("kOSProcessor"):doEvent("Open Terminal").

panels on.

// Main Loop
until (endProgram = true) {

    handleInput().
    printControlData().
    drawArrows().

    // Execute the reference to the current ship mode function
    shipModeRef().

    // Forces kOS to wait until the next physics tick to proceed with execution
    wait 0.
}

cleanUp().

function handleInput {
    if terminal:input:haschar {
        local charPressed to terminal:input:getchar().

        if (charPressed = "C") {
            set shipMode to "WAIT".
            set shipModeRef to doWait@.
            setTraverseRate(.5).
            clearBoard().
        } else if (charPressed = "R") {
            set shipMode to "RANDOM".
            set timer to time:seconds - 5.
            set shipModeRef to doModeRandom@.
            setTraverseRate(0.5).
        } else if (charPressed = "M") {
            set shipMode to "MOUNTAIN".
            set timer to time:seconds - 5.
            set shipModeRef to doModeMakeMountain@.
            setTraverseRate(3.5).
        } else if (charPressed = "I") {
            set shipMode to "ITERATOR".
            set timer to time:seconds - 5.
            set iterator to 0.
            set shipModeRef to doModeIterator@.
            setTraverseRate(10).
        } else if (charPressed = "V") {
            set shipMode to "WAVE".
            set waveDistance to 10.
            set shipModeRef to doModeWave@.
            setTraverseRate(3.5).
        } else if (charPressed = "T") {
            set shipMode to "TRAP".
            set shipModeRef to doModeTrap@.
            setTraverseRate(10).
        } else if (charPressed = "W") {
            set shipMode to "WAIT".
            set shipModeRef to doWait@.
        } else if (charPressed = "\") {
            set showArrows to not showArrows.
        } else if (charPressed = "/") {
            set endProgram to true.
        }
    }
}

function printControlData {
    clearScreen.

    print "---Moving Blocks Tutorial Program---".
    print "  shipMode:    " + shipMode.
    print "  showArrows:  " + showArrows.    
}

function clearBoard {
    for piston in pistons {
        piston:module:setField("Target Extension", 0).
    }
}

function doModeRandom {
    if (time:seconds - timer > 5) {
        set timer to time:seconds.
        for piston in pistons {
            piston:module:setField("Target Extension", 2.4 * random()).
        }
    }
}

function doModeMakeMountain {
    if (time:seconds - timer > 2) {

        clearExtensionMap().
        
        set timer to time:seconds.

        local randomPiston is floor(pistons:length * random()).
        local mountainTopHeight is 3.4 * random() + 1.4.
        set pistons[randomPiston]:targetExtensionUpdated to mountainTopHeight.

        local dropOffRate to 0.4 * random() + .5.

        recursiveMountainTerrainMapper(mountainTopHeight * .8, randomPiston, dropOffRate, .2).

        applyExtensionMap().
    }
}

function recursiveMountainTerrainMapper {
    parameter currentHeight.
    parameter originalPistonIdx.
    parameter dropOff.
    parameter threshold.

    if (currentHeight < threshold) {
        return.
    }

    for pistonIdx in pistons[originalPistonIdx]:neighbors {
        local neighboringPiston is pistons[pistonIdx].
        if (neighboringPiston:targetExtensionUpdated < currentHeight) {
            set neighboringPiston:targetExtensionUpdated to currentHeight * (1 + random() * 0.1).
            recursiveMountainTerrainMapper(currentHeight * dropOff, pistonIdx, dropOff, threshold).
        }   
    }
}

function doModeIterator {
    if (time:seconds - timer > .5 and iterator < pistons:length) {
        set timer to time:seconds.
        pistons[iterator]:module:setField("Target Extension", 2.4).
        set iterator to iterator + 1.
    }
}

function doModeWave {

    clearExtensionMap().

    if (waveDistance < 2) {
        set waveDistance to 13.
    }

    set waveDistance to waveDistance - 0.95.
    local waveDistanceMax is waveDistance + 0.9.
    local controlPartPosition is ship:controlPart:position.

    from {local i is 0.} until i >= pistons:length step {set i to i + 1.} do {            
        local vectorFromControlPart is pistons[i]:part:position - controlPartPosition.
        local topOnlyVector is vxcl(ship:facing:starvector, vectorFromControlPart).
        local topOnlyDistance is topOnlyVector:mag.

        if (topOnlyDistance > waveDistance and topOnlyDistance < waveDistanceMax) {

            set pistons[i]:targetExtensionUpdated to 1.2.
            recursiveMountainTerrainMapper(0.7, i, .4, .2).
        }
    }

    applyExtensionMap().
   
}

function doModeTrap {
    if (kerbalTarget = 0) {
        set kerbalTarget to vessel(KERBAL_TARGET_NAME).
    }

    for piston in pistons {
        
        local vectorToKerbal is kerbalTarget:position - piston:part:position.
        set vectorToKerbal to vxcl(ship:up:forevector, vectorToKerbal).
        if (vectorToKerbal:mag < 1.25) {
            if (piston:neighbors:length < 8) {  
                set piston:targetExtensionUpdated to 4.8.
            } else {
                set piston:targetExtensionUpdated to 3.6.
            }
        } else {
            set piston:targetExtensionUpdated to 0.
        }
    }

    applyExtensionMap().

}

function doWait {
    // Do Nothing at all.
}

function cleanUp {
    clearVecDraws().
    panels off.
}

function clearExtensionMap {
    for piston in pistons {
        set piston:targetExtensionUpdated to 0.
    }
}

function applyExtensionMap {
    for piston in pistons {
        local updatedPistonValue is piston:targetExtensionUpdated.

        if (updatedPistonValue <> piston:targetExtension) {
            piston:module:setField("Target Extension", updatedPistonValue).
            set piston:targetExtension to updatedPistonValue.
        }
    }
}

function drawArrows {
    if (showArrows) {
        VECDRAW(ship:controlPart:position, ship:facing:starvector * 20, RGB(0,0,1), "Top", 1.0, TRUE, 0.2, TRUE, TRUE).
    }
}

function setTraverseRate {
    parameter newTraverseRate.

    for piston in pistons {
        piston:module:setfield("traverse rate", newTraverseRate).
    }
}

function findParts {
    clearScreen.

    print "--Finding parts---".

    local pistonParts is ship:partsnamed("piston.03").

    for aPiston in pistonParts {
        local pistonModule is aPiston:getmodule("ModuleRoboticServoPiston").
        pistonModule:setfield("traverse rate", 10).
        pistonModule:setfield("damping", 100).

        local pistonLex is lexicon(
            "part", aPiston,
            "module", pistonModule,
            "targetExtension", 0,
            "targetExtensionUpdated", 0,
            "neighbors", list()
        ).

        pistons:add(pistonLex). 
    }

        // local shortestDistance to 10000000.

    from { local x is 0. } until x >= pistons:length step {set x to x + 1.} do {
        local aPiston is pistons[x]:part.
        local pistonNeighbors is list().
        from {local y is 0.} until y >= pistonParts:length step {set y to y + 1.} do {
            local innerPiston is pistons[y]:part.
            local distanceBetweenPistons is (aPiston:position - innerPiston:position):mag.
            // if (distanceBetweenPistons < shortestDistance and distanceBetweenPistons > 0.01) {
            //     set shortestDistance to distanceBetweenPistons.
            // }

            if (distanceBetweenPistons > 0.01 and distanceBetweenPistons < 1.5) {
                pistonNeighbors:add(y).
            } 
        }
        set pistons[x]:neighbors to (pistonNeighbors).
    }

    // print "totalPistonsFound: " + pistonParts:length.
    // print "shortestDistance: " + shortestDistance.

    // print "pistonNeighborsCT: " + neighboringModules:length.
    // for pm in neighboringModules {
    //     print "   - " + pm:length.
    // }

    // wait 10.
}
