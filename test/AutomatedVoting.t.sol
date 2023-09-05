// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AutomatedVoting} from "../src/AutomatedVoting.sol";
import {IAutomatedVoting} from "../src/interfaces/IAutomatedVoting.sol";
import {StakingRewards} from "../lib/token/contracts/StakingRewards.sol";
import {Kwenta} from "../lib/token/contracts/Kwenta.sol";
import {RewardEscrow} from "../lib/token/contracts/RewardEscrow.sol";
import {AutomatedVotingInternals} from "./AutomatedVotingInternals.sol";
import {Enums} from "../src/Enums.sol";

contract AutomatedVotingTest is Test {
    AutomatedVoting public automatedVoting;
    AutomatedVotingInternals public automatedVotingInternals;
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
        /// @dev this is so the time of lastScheduledElection is != 0
        vm.warp(block.timestamp + 3 weeks);
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
        address[] memory council = new address[](5);
        council[0] = user1;
        council[1] = user2;
        council[2] = user3;
        council[3] = user4;
        council[4] = user5;
        automatedVoting = new AutomatedVoting(council, address(stakingRewards));
        automatedVotingInternals = new AutomatedVotingInternals(
            council,
            address(stakingRewards)
        );
    }

    // onlyCouncil()

    function testOnlyCouncilSuccess() public {
        vm.prank(user1);
        automatedVoting.stepDown();
    }

    function testOnlyCouncilFail() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotCouncil.selector)
        );
        automatedVoting.stepDown();
    }

    // onlyStaker()

    // onlyDuringNomination()

    function testOnlyDuringNominationAtStart() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testFuzzOnlyDuringNomination(uint128 time) public {
        vm.assume(time <= 1 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.warp(block.timestamp + time);
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testOnlyDuringNominationLastSecond() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testOnlyDuringNominationPassed() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testOnlyDuringNominationNoElectionYet() public {
        vm.warp(block.timestamp + 23 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    // onlyDuringVoting()

    function testOnlyDuringVotingAtStart() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.nominateInFullElection(0, new address[](5));
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    function testFuzzOnlyDuringVoting(uint128 time) public {
        vm.assume(time <= 2 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        automatedVoting.nominateInFullElection(0, new address[](5));
        vm.warp(block.timestamp + time);
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    function testOnlyDuringVotingLastSecond() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        automatedVoting.nominateInFullElection(0, new address[](5));
        vm.warp(block.timestamp + 2 weeks);
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    function testOnlyDuringVotingPassed() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.nominateInFullElection(0, new address[](5));
        vm.warp(block.timestamp + 2 weeks + 1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    function testOnlyDuringVotingNotVotingYet() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);

        automatedVoting.nominateInFullElection(0, new address[](5));
        vm.warp(block.timestamp + 1 weeks - 1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    // getCouncil()

    function testGetCouncil() public {
        address[] memory result = automatedVoting.getCouncil();
        assertEq(result.length, 5);
        assertEq(result[0], user1);
    }

    // timeUntilNextScheduledElection()

    function testTimeUntilNextScheduledElection() public {
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 24 weeks);
    }

    function testTimeUntilNextScheduledElectionOverdue() public {
        vm.warp(block.timestamp + 24 weeks);
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 0);
    }

    function testTimeUntilNextScheduledElectionRightBeforeOverdue() public {
        vm.warp(block.timestamp + 24 weeks - 1);
        assertEq(automatedVoting.timeUntilNextScheduledElection(), 1);
    }

    function testFuzzTimeUntilNextScheduledElection(uint128 time) public {
        vm.assume(time < 24 weeks);
        vm.warp(block.timestamp + time);
        assertEq(
            automatedVoting.timeUntilNextScheduledElection(),
            24 weeks - time
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
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks);
    }

    function testTimeUntilElectionStateEndFinishedElection() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 0);
    }

    function testTimeUntilElectionStateEndRightBeforeFinish() public {
        /// @dev warp forward 24 weeks to get past the cooldown
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks - 1);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 1);
    }

    function testFuzzTimeUntilElectionStateEndNewScheduledElection(
        uint128 time
    ) public {
        vm.assume(time < 3 weeks);
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + time);
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks - time);
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
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(0);
        assertEq(automatedVoting.isElectionFinalized(0), true);
    }

    // startScheduledElection()

    function testFuzzStartScheduledElectionNotReady(uint128 time) public {
        vm.assume(time < 24 weeks);
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startScheduledElection();
    }

    function testStartScheduledElectionReady() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks);
        assertEq(automatedVoting.lastScheduledElection(), block.timestamp);
        assertEq(automatedVoting.electionNumbers(0), 0);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(0);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.scheduled);
    }

    // startCouncilElection()

    function testStartCouncilElectionSuccess() public {
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user1, user5), true);
        assertEq(automatedVoting.removalVotes(user5), 1);
        vm.prank(user2);
        automatedVoting.startCouncilElection(user5);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user2, user5), true);
        assertEq(automatedVoting.removalVotes(user5), 2);
        /// @dev member is booted after the third vote, election starts, and accounting is cleared
        vm.prank(user3);
        automatedVoting.startCouncilElection(user5);
        
        /// @dev check accounting
        assertEq(automatedVoting.isCouncilMember(user5), false);
        assertEq(automatedVoting.removalVotes(user5), 0);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user1, user5), false);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user2, user5), false);
        assertEq(automatedVoting.hasVotedForMemberRemoval(user3, user5), false);

        /// @dev check election
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks);
        assertEq(automatedVoting.lastScheduledElection(), block.timestamp);
        assertEq(automatedVoting.electionNumbers(0), 0);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(0);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.council);
    }

    function testStartCouncilElectionNotCouncil() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotCouncil.selector)
        );
        automatedVoting.startCouncilElection(user5);
    }

    function testStartCouncilElectionMemeberToRemoveNotOnCoucil() public {
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.MemberNotOnCouncil.selector
            )
        );
        automatedVoting.startCouncilElection(address(this));
    }

    function testStartCouncilElectionAlreadyVoted() public {
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        vm.prank(user1);
        automatedVoting.startCouncilElection(user5);
    }

    // startCKIPelection()

    function testStartCKIPElectionSuccess() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();

        /// @dev check election
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks);
        assertEq(automatedVoting.lastScheduledElection(), block.timestamp);
        assertEq(automatedVoting.electionNumbers(0), 0);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(0);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.CKIP);
    }

    function testStartCKIPElectionNotStaked() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.startCKIPElection();
    }

    function testStartCKIPElectionNotReadyToStart() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startCKIPElection();
    }

    function testFuzzStartCKIPElectionNotReadyToStart(uint time) public {
        vm.assume(time < 3 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();
        vm.warp(block.timestamp + time);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeStarted.selector
            )
        );
        automatedVoting.startCKIPElection();
    }

    function testStartCKIPElectionImmediatelyAfterCooldown() public {
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        automatedVoting.startCKIPElection();
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.startCKIPElection();
    }

    // stepDown()

    function testStepDownSuccess() public {
        vm.prank(user1);
        automatedVoting.stepDown();

        assertFalse(automatedVoting.isCouncilMember(user1));
        assertEq(automatedVoting.timeUntilElectionStateEnd(0), 3 weeks);
        assertEq(automatedVoting.electionNumbers(0), 0);
        (
            uint256 electionStartTime,
            uint256 endTime,
            bool isFinalized,
            Enums.electionType theElectionType
        ) = automatedVoting.elections(0);
        assertEq(electionStartTime, block.timestamp);
        assertEq(endTime, block.timestamp + 3 weeks);
        assertEq(isFinalized, false);
        assertTrue(theElectionType == Enums.electionType.stepDown);
    }

    function testStepDownNotCouncil() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotCouncil.selector)
        );
        automatedVoting.stepDown();
    }

    function testStepDownCannotStepDown() public {
        vm.prank(user1);
        automatedVoting.stepDown();
        vm.prank(user3);
        automatedVoting.stepDown();
        vm.prank(user4);
        automatedVoting.stepDown();
        vm.prank(user5);
        automatedVoting.stepDown();
        /// @dev cant step down because they are last member
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.CouncilMemberCannotStepDown.selector
            )
        );
        vm.prank(user2);
        automatedVoting.stepDown();
    }

    // finalizeElection()

    function testFinalizeElectionAlreadyFinalized() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks);
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
        vm.warp(block.timestamp + 3 weeks);
        automatedVoting.finalizeElection(0);
        assertEq(automatedVoting.isElectionFinalized(0), true);
    }

    function testFuzzFinalizeElectionNotReady(uint128 time) public {
        vm.assume(time < 3 weeks);
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

    function testFinalizeElectionNotReady() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAutomatedVoting.ElectionNotReadyToBeFinalized.selector
            )
        );
        automatedVoting.finalizeElection(0);
    }

    // nominateInSingleElection()

    function testNominateInSingleElectionSuccess() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();

        automatedVoting.nominateInSingleElection(0, user1);
        assertEq(automatedVoting.isNominated(0, user1), true);
    }

    function testNominateInSingleElectionNotStaked() public {
        vm.warp(block.timestamp + 24 weeks);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.nominateInSingleElection(0, user1);
    }

    function testNominateInSingleElectionNotDuringNomination() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.warp(block.timestamp + 1 weeks + 1);
        
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInSingleElection(0, user1);
    }

    function testNominateInSingleElectionNotSingleElection() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        
        vm.expectRevert("Election not a single election");
        automatedVoting.nominateInSingleElection(0, user1);
    }

    // voteInSingleElection()

    function testVoteInSingleElectionSuccess() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();

        automatedVoting.nominateInSingleElection(0, user1);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInSingleElection(0, user1);
        assertEq(automatedVoting.voteCounts(0, user1), 1);
    }

    function testVoteInSingleElectionNotStaked() public {
        vm.warp(block.timestamp + 24 weeks);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.voteInSingleElection(0, user1);
    }

    function testVoteInSingleElectionNotDuringVoting() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();

        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInSingleElection(0, user1);
    }

    function testVoteInSingleElectionAlreadyEnded() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInSingleElection(0, user1);
    }

    function testVoteInSingleElectionNotSingleElection() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.warp(block.timestamp + 1 weeks + 1);

        vm.expectRevert("Election not a single election");
        automatedVoting.voteInSingleElection(0, user1);
    }

    function testVoteInSingleElectionAlreadyVoted() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 2);
        kwenta.approve(address(stakingRewards), 2);
        stakingRewards.stake(2);
        vm.prank(user2);
        automatedVoting.stepDown();

        automatedVoting.nominateInSingleElection(0, user1);
        vm.warp(block.timestamp + 1 weeks + 1);
        automatedVoting.voteInSingleElection(0, user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        automatedVoting.voteInSingleElection(0, user1);
    }

    function testVoteInSingleElectionCandidateNotNominated() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 2);
        kwenta.approve(address(stakingRewards), 2);
        stakingRewards.stake(2);
        vm.prank(user2);
        automatedVoting.stepDown();
        vm.warp(block.timestamp + 1 weeks + 1);
        
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CandidateNotNominated.selector)
        );
        automatedVoting.voteInSingleElection(0, user1);
    }

    // nominateInFullElection()

    function testNominateInFullElectionSuccess() public {
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
        automatedVoting.nominateInFullElection(0, candidates);

        //todo: check the candidateAddresses array
        assertEq(automatedVoting.isNominated(0, user1), true);
        assertEq(automatedVoting.isNominated(0, user2), true);
        assertEq(automatedVoting.isNominated(0, user3), true);
        assertEq(automatedVoting.isNominated(0, user4), true);
        assertEq(automatedVoting.isNominated(0, user5), true);
    }

    function testNominateInFullElectionNotStaked() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        automatedVoting.nominateInFullElection(0, candidates);
    }

    function testNominateInFullElectionNotElection() public {
        vm.warp(block.timestamp + 23 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testNominateInFullElectionNominatingEnded() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 1 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in nomination state");
        automatedVoting.nominateInFullElection(0, new address[](5));
    }

    function testNominateInFullElectionNotFullElection() public {
        vm.warp(block.timestamp + 24 weeks);
        vm.prank(user2);
        automatedVoting.stepDown();
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

        vm.expectRevert("Election not a full election");
        automatedVoting.nominateInFullElection(0, candidates);
    }

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
        automatedVoting.nominateInFullElection(0, candidates);
        vm.warp(block.timestamp + 1 weeks);
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
            abi.encodeWithSelector(IAutomatedVoting.CallerNotStaked.selector)
        );
        vm.startPrank(user1);
        automatedVoting.voteInFullElection(0, candidates);
    }

    function testVoteInFullElectionNotElection() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    function testVoteInFullElectionAlreadyEnded() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        vm.warp(block.timestamp + 3 weeks + 1);
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.expectRevert("Election not in voting state");
        automatedVoting.voteInFullElection(0, new address[](5));
    }

    function testVoteInFullElectionTooManyCandidates() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 1);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        address[] memory candidates = new address[](6);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        candidates[5] = admin;
        vm.warp(block.timestamp + 1 weeks);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.TooManyCandidates.selector)
        );
        automatedVoting.voteInFullElection(0, candidates);
    }

    function testVoteInFullElectionAlreadyVoted() public {
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
        automatedVoting.nominateInFullElection(0, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(0, candidates);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.AlreadyVoted.selector)
        );
        automatedVoting.voteInFullElection(0, candidates);
    }

    function testVoteInFullElectionCandidateNotNominated() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVoting.startScheduledElection();
        kwenta.transfer(user1, 2);
        vm.startPrank(user1);
        kwenta.approve(address(stakingRewards), 2);
        stakingRewards.stake(2);
        address[] memory candidates = new address[](5);
        candidates[0] = user1;
        candidates[1] = user2;
        candidates[2] = user3;
        candidates[3] = user4;
        candidates[4] = user5;
        vm.warp(block.timestamp + 1 weeks);
        vm.expectRevert(
            abi.encodeWithSelector(IAutomatedVoting.CandidateNotNominated.selector)
        );
        automatedVoting.voteInFullElection(0, candidates);
    }

    // isCouncilMember()

    function testIsCouncilMember() public {
        assertEq(automatedVoting.isCouncilMember(user1), true);
    }

    function testIsNotCouncilMember() public {
        assertEq(automatedVoting.isCouncilMember(address(0x2)), false);
    }

    // _isStaker()

    // _checkIfQuorumReached()

    // _finalizeElection()

    function testFinalizeElectionInternal() public {
        vm.warp(block.timestamp + 24 weeks);
        automatedVotingInternals.startScheduledElection();
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
        automatedVotingInternals.nominateInFullElection(0, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVotingInternals.voteInFullElection(0, candidates);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVotingInternals.finalizeElectionInternal(0);
        assertEq(automatedVotingInternals.isElectionFinalized(0), true);

        /// @dev check if the council changed
        assertEq(automatedVotingInternals.getCouncil(), candidates);
    }

    // getWinners()

    function testGetWinners() public {
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
        automatedVoting.nominateInFullElection(0, candidates);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInFullElection(0, candidates);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(0);

        (address[] memory winners, uint256[] memory votes) = automatedVoting
            .getWinners(0, 5);
        assertEq(winners.length, 5);
        assertEq(votes.length, 5);
        assertEq(winners[0], user1);
        assertEq(winners[1], user2);
        assertEq(winners[2], user3);
        assertEq(winners[3], user4);
        assertEq(winners[4], user5);
    }

    function testGetWinnersStepDown() public {
        vm.warp(block.timestamp + 24 weeks);
        kwenta.transfer(user1, 1);
        kwenta.approve(address(stakingRewards), 1);
        stakingRewards.stake(1);
        vm.prank(user2);
        automatedVoting.stepDown();
        automatedVoting.nominateInSingleElection(0, user1);
        vm.warp(block.timestamp + 1 weeks);
        automatedVoting.voteInSingleElection(0, user1);
        assertEq(automatedVoting.voteCounts(0, user1), 1);
        vm.warp(block.timestamp + 3 weeks + 1);
        automatedVoting.finalizeElection(0);

        (address[] memory winners, uint256[] memory votes) = automatedVoting
            .getWinners(0, 1);
        assertEq(winners.length, 1);
        assertEq(votes.length, 1);
        assertEq(winners[0], user1);
        /// @dev reverts because index out of bounds (should do that)
        vm.expectRevert();
        assertEq(winners[1], user2);
    }

    //todo: test getWinners more (scrutinize it with a lot of fuzzing)

    // isWinner()

    function testIsWinner() public {
        address[] memory winners = new address[](1);
        winners[0] = user1;
        assertEq(
            automatedVotingInternals.isWinnerInternal(user1, winners, 1),
            true
        );
    }

    function testIsNotWinner() public {
        address[] memory winners = new address[](1);
        winners[0] = user1;
        assertEq(
            automatedVotingInternals.isWinnerInternal(user2, winners, 1),
            false
        );
    }

    //todo: test isWinner for the < upToIndex change

    //todo: test everything with when a non-existent election is put in

    //todo: test onlyFullElection

    //todo: test elections like CKIP reelection for when another re-election
    // is started right at 3 weeks end but the first election is not finalized yet

    /// @dev create a new user address
    function createUser() public returns (address) {
        userNonce++;
        return vm.addr(userNonce);
    }
}
