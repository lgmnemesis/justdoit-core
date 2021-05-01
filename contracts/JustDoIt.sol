// SPDX-License-Identifier: MIT
pragma solidity >=0.7 <0.9.0;

import './JDIToken.sol';

contract JustDoIt {

    JDIToken public jdiToken;
    enum Result {Initial, Success, Failure}

    struct Challenge {
        bytes32 id;
        address owner;
        uint amountStaked;
        uint deadline;
        uint supprtersAmountStaked;
        Result resultFromOwner;
        uint successes;
        uint failures;
        bool canBeRewarded;
        bool gotFees;
        uint supporters;
    }

    struct Supporting {
        uint amountStaked;
        bool gotRewards;
        Result result;
    }

    address public deployer;
    uint public totalFeesAmount = 0;
    mapping(address => mapping(bytes32 => Supporting)) public supporters;
    mapping(bytes32 => Challenge) public challenges;

    event ChallengeAdded(bytes32 id, address indexed owner, string name, uint amountStaked, string token, uint indexed deadline);
    event SupportChallenge(address indexed supporter, bytes32 indexed id, uint amountStaked);
    event OwnerReportResult(bytes32 id, address indexed owner, Result result);
    event SupporterReportResult(bytes32 id, address indexed supporter, Result result);

    constructor(address _deployer, address _jdiToken) {
        deployer = _deployer;
        jdiToken = JDIToken(_jdiToken);
    }

    function getFinalResult(bytes32 _id) challengeIsOver(_id) external view returns(Result) {
        return _getFinalResult(_id);
    }

    function getFees(bytes32 _id) challengeIsOver(_id) external view returns (uint) {
        return _getFees(_id);
    }

    function getOwnerRewards(bytes32 _id) challengeIsOver(_id) external view returns (uint, uint) {
        Challenge memory challenge = _getChallenge(_id);
        require(challenge.owner == msg.sender, 'You are NOT the owner');
        return _getOwnerRewards(_id, challenge);
    }

    function getSupporterRewards(bytes32 _id) challengeIsOver(_id) external view returns (uint, uint) {
        Challenge memory challenge = _getChallenge(_id);
        require(challenge.owner != msg.sender, 'You are the owner');
        return _getSupporterRewards(_id);
    }

    function _getChallenge(bytes32 _id) challengeExists(_id) internal view returns (Challenge memory) {
        return challenges[_id];
    }

    function _getFinalResult(bytes32 _id) internal view returns(Result) {
        Challenge memory challenge = _getChallenge(_id);
        uint votedSuccess = challenge.successes;
        uint votedFailure = challenge.failures;
        Result finalResult = Result.Failure;
        if (challenge.resultFromOwner == Result.Success && votedSuccess >= votedFailure) {
            finalResult = Result.Success;
        }
        return finalResult;
    }

    function _getFees(bytes32 _id) internal view returns (uint) {
        Challenge memory challenge = _getChallenge(_id);
        if (_getFinalResult(_id) != challenge.resultFromOwner) {
            return challenge.amountStaked;
        }
        return 0;
    }

    function _getOwnerRewards(bytes32 _id, Challenge memory challenge) internal view returns (uint, uint) {
        Result finalResult = _getFinalResult(_id);
        Result ownerResult = challenge.resultFromOwner;
        if (finalResult == ownerResult) {
            // 1. If Success, receive his original staking + all supporters staking amounts.
            uint amountStaked = finalResult == Result.Success ? challenge.amountStaked + challenge.supprtersAmountStaked: 0;

            // 2. Receive 1% of the staked amount in JDI tokens for trying to or completing the challenge.
            uint JDIAmount = (challenge.amountStaked + challenge.supprtersAmountStaked) / 100;
            return (amountStaked, JDIAmount);
        } else {
            // Nothing
            return (0, 0);
        }
    }

    function _getSupporterRewards(bytes32 _id) internal view returns (uint , uint) {
        Result finalResult = _getFinalResult(_id);
        Result supporterResult = supporters[msg.sender][_id].result;
        if (finalResult == supporterResult) {
            // 1. Incase of a failure, should receive his staked amount.
            uint amountStaked = finalResult == Result.Failure ? supporters[msg.sender][_id].amountStaked : 0;

            // 2. Receive his proportional share from 30% of the amount staked, in JDI tokens, for supporting and voting honestly.
            Challenge memory challenge = _getChallenge(_id);
            uint totalAmount = challenge.supprtersAmountStaked;
            uint totalShare = totalAmount * 30 / 100;
            uint JDIAmount = totalShare * supporters[msg.sender][_id].amountStaked / totalAmount;

            return (amountStaked, JDIAmount);
        } else {
            // Nothing
            return (0, 0);
        }
    }

    function addChallengeETH(bytes32 _id, string memory _name, uint _deadline) external payable {
        require(msg.value > 0, 'No funds supplied');
        require(_deadline >= block.timestamp + 1 days, 'Deadline too short');
        require(challenges[_id].deadline == 0, 'Challenge already exists');
        challenges[_id]  = Challenge(_id, msg.sender, msg.value, _deadline, 0, Result.Initial, 0, 0, true, false, 0);
        emit ChallengeAdded(_id, msg.sender, _name, msg.value, 'ETH', _deadline);
    }

    function supportChallenge(bytes32 _id) challengeExists(_id) external payable {
        require(msg.value > 0, 'No funds supplied');
        require(challenges[_id].owner != msg.sender, 'You are the owner');
        require(challenges[_id].deadline > block.timestamp, 'Challenge deadline is over');
        supporters[msg.sender][_id].amountStaked += msg.value;
        challenges[_id].supprtersAmountStaked += msg.value;
        if (supporters[msg.sender][_id].amountStaked == msg.value) {
            challenges[_id].supporters++;
        }
        emit SupportChallenge(msg.sender, _id, msg.value);
    }

    function supporterReportResult(bytes32 _id, Result _result) canReport(_id, false) external {
        require(_result != Result.Initial, 'Can only report Success or Failure');
        _result == Result.Success ? challenges[_id].successes++ : challenges[_id].failures++;
        supporters[msg.sender][_id].result = _result; 
        emit SupporterReportResult(_id, msg.sender, _result);
    }
    
    function ownerReportResult(bytes32 _id, Result _result) canReport(_id, true) external {
        require(_result != Result.Initial, 'Can only report Success or Failure');
        challenges[_id].resultFromOwner = _result;
        emit OwnerReportResult(_id, msg.sender, _result);
    }

    function collectOwnerRewards(bytes32 _id) challengeIsOver(_id) external {
        require(challenges[_id].owner == msg.sender, 'You are NOT the owner');
        require(challenges[_id].canBeRewarded, 'No more rewards');
        (uint amountStaked, uint JDIAmount) = _getOwnerRewards(_id, challenges[_id]);

        challenges[_id].canBeRewarded = false;
        if (JDIAmount > 0) {
            jdiToken.mint(msg.sender, JDIAmount);
        }

        if (amountStaked > 0) {
            payable(msg.sender).transfer(amountStaked);
        }
    }

    function collectSupporterRewards(bytes32 _id) challengeIsOver(_id) external {
        require(!supporters[msg.sender][_id].gotRewards, 'No more rewards');
        require(supporters[msg.sender][_id].amountStaked > 0, 'You are not supporting this challenge');
        (uint amountStaked, uint JDIAmount) = _getSupporterRewards(_id);

        supporters[msg.sender][_id].gotRewards = true;
        if (JDIAmount > 0) {
            jdiToken.mint(msg.sender, JDIAmount);
        }

        if (amountStaked > 0) {
            payable(msg.sender).transfer(amountStaked);
        }
    }

    function collectChallengeFees(bytes32 _id) challengeIsOver(_id) external {
        require(!challenges[_id].gotFees, 'No more fees');
        challenges[_id].gotFees = true;
        uint amountStaked = _getFees(_id);
        totalFeesAmount += amountStaked;
        jdiToken.mint(address(this), amountStaked * 2 / 1000); // 0.2%
    }

    function collectFees() external {
        require(msg.sender == deployer, 'Only deployer');
        require(totalFeesAmount > 0, 'No fees');
        uint total = totalFeesAmount;
        totalFeesAmount = 0;
        payable(deployer).transfer(total);
        jdiToken.burn(address(this), jdiToken.balanceOf(address(this)) * 10 / 100);
        jdiToken.transfer(deployer, jdiToken.balanceOf(address(this)));
    }

    function isReportTime(bytes32 _id, bool isOwner) public view returns (bool) {
        return  block.timestamp > challenges[_id].deadline &&
                block.timestamp <= challenges[_id].deadline + (isOwner ? 2 days : 1 weeks);
    }

    function _isChallengeExists(bytes32 _id) internal view returns(bool) {
        return challenges[_id].deadline > 0;
    }

    modifier challengeExists(bytes32 _id) {
        require(_isChallengeExists(_id), 'Challenge not found');
        _;
    }

    modifier canReport(bytes32 _id, bool isOwner) {
        require(_isChallengeExists(_id), 'Challenge not found');
        require(isReportTime(_id, isOwner), 'Not in a report time window');
        if (isOwner) {
            require(challenges[_id].owner == msg.sender, 'Not your challenge');
        } else {
            require(supporters[msg.sender][_id].amountStaked > 0, 'You are not supporting this challenge');
            require(challenges[_id].resultFromOwner == Result.Success, 'Owner did not report any result yet or reported failure');
        }
        _;
    }

    modifier challengeIsOver(bytes32 _id) {
        require(_isChallengeExists(_id), 'Challenge not found');
        require(block.timestamp > challenges[_id].deadline + 1 weeks, 'Challenge reporting is still going');
        _;
    }
}