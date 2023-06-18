@lazyGlobal off.

local A_CONSTANT is "NO_CHANGES".

local shipMode is "WAIT".
local shipModeRef is doWait@.
local endProgram is false.
local showArrows is false.

findParts().

// Open terminal window automatically
core:part:getModule("kOSProcessor"):doEvent("Open Terminal").

// Main Loop
until (endProgram = true) {

    handleInput().
    printControlData().

    // Execute the reference to the current ship mode function
    shipModeRef().

    // Forces kOS to wait until the next physics tick to proceed with execution
    wait 0.
}

cleanUp().



function handleInput {
    if terminal:input:haschar {
        local charPressed is terminal:input:getchar().

        if (charPressed = "A") {
            set shipMode to "MODE_A".
            set shipModeRef to doModeA@.
        } else if (charPressed = "B") {
            set shipMode to "MODE_B".
            set shipModeRef to doModeB@.
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

    print "---Template Program---".
    print "  shipMode:    " + shipMode.
    print "  showArrows:  " + showArrows.
}

function doModeA {
    // Do Mode A
}

function doModeB {
    // Do Mode B
}

function doWait {
    // Do Nothing at all.
}

function cleanUp {
    clearVecDraws().
}

function findParts {
    // Find and creates references to all parts at startup
}
