// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {AutomatedVoting} from "../src/AutomatedVoting.sol";
import {IAutomatedVoting} from "../src/interfaces/IAutomatedVoting.sol";
import {StakingRewards} from "../lib/token/contracts/StakingRewards.sol";
import {Kwenta} from "../lib/token/contracts/Kwenta.sol";
import {RewardEscrow} from "../lib/token/contracts/RewardEscrow.sol";

contract AutomatedVotingTest is Test {
    struct election {
        uint256 startTime;
        uint256 endTime;
        bool isFinalized;
        string electionType;
        address[] candidateAddresses; // Array of candidate addresses for this election
        address[] winningCandidates; // Array of candidates that won
    }

    AutomatedVoting public automatedVoting;
    StakingRewards public stakingRewards;
    Kwenta public kwenta;
    RewardEscrow public rewardEscrow;
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;
    address public user5;
    uint256 public userNonce;
    uint256 public startTime;

    function setUp() public {
        startTime = block.timestamp;
        admin = createUser();
        user1 = createUser();
        user2 = createUser();
        user3 = createUser();
        user4 = createUser();
        user5 = createUser();
        kwenta = new Kwenta("Kwenta", "Kwe", 100_000, admin, address(this));
        rewardEscrow = new RewardEscrow(admin, address(kwenta));
        stakingRewards = new StakingRewards(
            address(kwenta),
            address(rewardEscrow),
            address(this)
        );
        address[] memory council = new address[](1);
        council[0] = address(0x1);
        automatedVoting = new AutomatedVoting(council, address(stakingRewards));
    }

    // getCouncil()

    function testGetCouncil() public {
        address[] memory result = automatedVoting.getCouncil();
        assertEq(result.length, 1, "Council should have 1 member");
        assertEq(result[0], address(0x1), "Council member should be 0x1");
    }

    // timeUntilNextScheduledElection()

    function testTimeUntilNextScheduledElection() public {
        assertEq(
            automatedVoting.timeUntilNextScheduledElection(),
            24 weeks - startTime
        );
    }

    function testTimeUntilNextScheduledElectionOverdue() public {
        vm.warp(block.timestamp + 24 weeks);
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 0);
    }

    function testFuzzTimeUntilNextScheduledElection(uint128 time) public {
        vm.assume(time < 24 weeks);
        vm.warp(block.timestamp + time);
        assertEq(
            automatedVoting.timeUntilNextScheduledElection(),
            24 weeks - startTime - time
        );
    }

    // timeUntilElectionStateEnd()

    function testTimeUntilElectionStateEndNoElection() public {
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 0);
    }

    function testTimeUntilElectionStateEndNewScheduledElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 2 weeks);
    }

    function testTimeUntilElectionStateEndFinishedElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 2 weeks);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 0);
    }

    function testTimeUntilElectionStateEndOtherElections() public {
        //todo: test other election states
    }

    function testFuzzTimeUntilElectionStateEndNewScheduledElection(
        uint128 time
    ) public {
        vm.assume(time < 2 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 2 weeks - time);
    }

    // isElectionFinalized()

    function testIsElectionFinalizedNoElection() public {
        assertEq(automatedVoting.isElectionFinalized(0), false);
    }

    function testIsElectionFinalizedNewElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.isElectionFinalized(0), false);
    }

    function testIsElectionFinalizedFinishedElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 2 weeks + 1);
        automatedVoting.finalizeElection(0);
        assertEq(automatedVoting.isElectionFinalized(0), true);
    }

    // startScheduledElection()

    function testFuzzStartScheduledElectionNotReady(uint128 time) public {
        vm.assume(time < 24 weeks);
        vm.warp(block.timestamp + time - startTime);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startScheduledElection();
    }

    function testStartScheduledElectionReady() public {
        vm.warp(block.timestamp + 24 weeks - startTime);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 2 weeks);
        assertEq(automatedVoting.lastScheduledElection(), block.timestamp);
        assertEq(automatedVoting.electionNumbers(0), 0);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            string memory electionType
        ) = automatedVoting.elections(0);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 2 weeks);
        assertEq(isFinalized, false);
        assertEq(electionType, "full");
    }

    // startCouncilElection()

    // startCKIPelection()

    // stepDown()

    // finalizeElection()

    function testFinalizeElectionAlreadyFinalized() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 2 weeks + 1);
        automatedVoting.finalizeElection(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionAlreadyFinalized.selector
            )
        );
        automatedVoting.finalizeElection(0);
    }

    function testFinalizeElection() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 2 weeks + 1);
        automatedVoting.finalizeElection(0);
        assertEq(automatedVoting.isElectionFinalized(0), true);
    }

    function testFuzzFinalizeElectionNotReady(uint128 time) public {
        vm.assume(time < 2 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeFinalized.selector
            )
        );
        automatedVoting.finalizeElection(0);
    }

    // voteInSingleElection()

    // voteInFullElection()

    function testVoteInFullElectionSuccess() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        automatedVoting.voteInFullElection(0, candidates);

        //todo: check the candidateAddresses array
        uint user1Votes = automatedVoting.voteCounts(0, user1);
        assertEq(user1Votes, 1);
        uint user2Votes = automatedVoting.voteCounts(0, user2);
        assertEq(user2Votes, 1);
        uint user3Votes = automatedVoting.voteCounts(0, user3);
        assertEq(user3Votes, 1);
        uint user4Votes = automatedVoting.voteCounts(0, user4);
        assertEq(user4Votes, 1);
        uint user5Votes = automatedVoting.voteCounts(0, user5);
        assertEq(user5Votes, 1);
        uint adminVotes = automatedVoting.voteCounts(0, admin);
        assertEq(adminVotes, 0);
    }

    function testVoteInFullElectionNotStaked() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CallerNotStaked.selector
            )
        );
        vm.startPrank(user1);
        automatedVoting.voteInFullElection(0, candidates);
    }

    //todo: test everything with when a non-existent election is put in

    /// @dev create a new user address
    function createUser() public returns (address) {
        userNonce++;
        return vm.addr(userNonce);
    }
}
