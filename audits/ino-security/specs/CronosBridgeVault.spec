// Draft CVL. Not typechecked or proved; no authorized prover access configured.
// Do not summarize the token's mutating calls as success or assume a quorum.
methods {
    function paused() external returns (bool) envfree;
    function processedBurns(bytes32) external returns (bool) envfree;
    function releasedToday() external returns (uint256) envfree;
}

rule pausedReleaseReverts(bytes32 burn, address recipient, uint256 amount,
                          uint64 version, uint256 deadline, bytes[] signatures) {
    env e;
    require paused();
    release@withrevert(e, burn, recipient, amount, version, deadline, signatures);
    bool reverted = lastReverted;
    assert reverted;
}

rule consumedBurnCannotReleaseAgain(bytes32 burn, address recipient, uint256 amount,
                                    uint64 version, uint256 deadline, bytes[] signatures) {
    env e;
    require processedBurns(burn);
    release@withrevert(e, burn, recipient, amount, version, deadline, signatures);
    bool reverted = lastReverted;
    assert reverted;
}

rule failedReleasePreservesAccounting(bytes32 burn, address recipient, uint256 amount,
                                     uint64 version, uint256 deadline, bytes[] signatures) {
    env e;
    bool beforeProcessed = processedBurns(burn);
    uint256 beforeReleased = releasedToday();
    release@withrevert(e, burn, recipient, amount, version, deadline, signatures);
    bool reverted = lastReverted;
    bool afterProcessed = processedBurns(burn);
    uint256 afterReleased = releasedToday();
    assert reverted => (beforeProcessed == afterProcessed && beforeReleased == afterReleased);
}

rule processedBurnNeverClears(bytes32 burn) {
    env e;
    method f;
    calldataarg args;
    require processedBurns(burn);
    f@withrevert(e, args);
    assert processedBurns(burn);
}
