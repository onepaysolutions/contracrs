// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../access/AccessControl.sol";

interface IOPSPresale {
    function notifyPriceChange(uint256 newPrice) external;
}

interface IAirdropManager {
    function notifyPriceChange(uint256 newPrice) external;
}

contract PriceController is AccessControl {
    struct Phase {
        uint256 basePrice;    // Base price for this phase (e.g., 0.30 USD)
        uint256 currentPrice; // Current price after adjustments
        uint256 soldAmount;   // Amount sold in current phase
        bool completed;       // Whether phase is completed
    }

    // Constants
    uint256 public constant PRICE_INCREMENT = 0.01e18;  // 0.01 USD price increment
    uint256 public constant VOLUME_STEP = 100000e18;    // 100,000 OPS per step
    uint256 public constant PHASE_MAX_STEPS = 20;       // Maximum 20 price increases per phase

    // Contract references
    IOPSPresale public opsPresale;
    IAirdropManager public airdropManager;

    // Phase configuration
    Phase[] public phases;
    uint256 public currentPhaseIndex;

    // Events
    event PriceIncreased(uint256 indexed phaseIndex, uint256 newPrice);
    event PhaseCompleted(uint256 indexed phaseIndex, uint256 timestamp);
    event PhaseAdvanced(uint256 indexed newPhaseIndex, uint256 newBasePrice);
    event ContractsUpdated(address opsPresale, address airdropManager);

    constructor(
        address initialOwner,
        address _opsPresale,
        address _airdropManager
    ) AccessControl(initialOwner) {
        opsPresale = IOPSPresale(_opsPresale);
        airdropManager = IAirdropManager(_airdropManager);

        // Initialize first 4 phases with their base prices
        phases.push(Phase({
            basePrice: 0.30e18,  // Phase 1: 0.30 USD
            currentPrice: 0.30e18,
            soldAmount: 0,
            completed: false
        }));
        
        phases.push(Phase({
            basePrice: 0.32e18,  // Phase 2: 0.32 USD
            currentPrice: 0.32e18,
            soldAmount: 0,
            completed: false
        }));
        
        phases.push(Phase({
            basePrice: 0.34e18,  // Phase 3: 0.34 USD
            currentPrice: 0.34e18,
            soldAmount: 0,
            completed: false
        }));
        
        phases.push(Phase({
            basePrice: 0.36e18,  // Phase 4: 0.36 USD
            currentPrice: 0.36e18,
            soldAmount: 0,
            completed: false
        }));
    }

    // Update contract references
    function updateContracts(
        address _opsPresale,
        address _airdropManager
    ) external onlyOwner {
        if (_opsPresale != address(0)) {
            opsPresale = IOPSPresale(_opsPresale);
        }
        if (_airdropManager != address(0)) {
            airdropManager = IAirdropManager(_airdropManager);
        }
        emit ContractsUpdated(address(opsPresale), address(airdropManager));
    }

    // Update sold amount and adjust price if needed
    function updateSold(uint256 amount) external onlyOperator {
        require(currentPhaseIndex < phases.length, "No active phase");
        Phase storage currentPhase = phases[currentPhaseIndex];
        require(!currentPhase.completed, "Phase completed");

        currentPhase.soldAmount += amount;

        // Calculate how many price steps should have occurred
        uint256 steps = currentPhase.soldAmount / VOLUME_STEP;
        
        // Limit maximum steps
        if (steps > PHASE_MAX_STEPS) {
            steps = PHASE_MAX_STEPS;
            currentPhase.completed = true;
            emit PhaseCompleted(currentPhaseIndex, block.timestamp);
        }

        // Calculate new price
        uint256 newPrice = currentPhase.basePrice + (steps * PRICE_INCREMENT);
        
        // Update price if changed
        if (newPrice != currentPhase.currentPrice) {
            currentPhase.currentPrice = newPrice;
            
            // Notify other contracts about price change
            opsPresale.notifyPriceChange(newPrice);
            airdropManager.notifyPriceChange(newPrice);
            
            emit PriceIncreased(currentPhaseIndex, newPrice);
        }
    }

    // Get current price
    function getCurrentPrice() external view returns (uint256) {
        require(currentPhaseIndex < phases.length, "No active phase");
        return phases[currentPhaseIndex].currentPrice;
    }

    // Get next phase's base price
    function getNextPhasePrice() external view returns (uint256) {
        require(currentPhaseIndex + 1 < phases.length, "No next phase");
        return phases[currentPhaseIndex + 1].basePrice;
    }

    // Advance to next phase
    function advancePhase() external onlyOperator returns (bool) {
        require(currentPhaseIndex < phases.length, "No active phase");
        require(phases[currentPhaseIndex].completed, "Current phase not completed");
        
        if (currentPhaseIndex + 1 >= phases.length) {
            return false;
        }

        currentPhaseIndex++;
        uint256 newBasePrice = phases[currentPhaseIndex].basePrice;

        // Notify other contracts about new phase price
        opsPresale.notifyPriceChange(newBasePrice);
        airdropManager.notifyPriceChange(newBasePrice);

        emit PhaseAdvanced(currentPhaseIndex, newBasePrice);
        return true;
    }

    // Get current phase info
    function getCurrentPhaseInfo() external view returns (
        uint256 phaseIndex,
        uint256 basePrice,
        uint256 currentPrice,
        uint256 soldAmount,
        bool completed
    ) {
        require(currentPhaseIndex < phases.length, "No active phase");
        Phase storage phase = phases[currentPhaseIndex];
        return (
            currentPhaseIndex,
            phase.basePrice,
            phase.currentPrice,
            phase.soldAmount,
            phase.completed
        );
    }

    // Check if current phase is completed
    function isPhaseCompleted() external view returns (bool) {
        if (currentPhaseIndex >= phases.length) return true;
        return phases[currentPhaseIndex].completed;
    }
}
