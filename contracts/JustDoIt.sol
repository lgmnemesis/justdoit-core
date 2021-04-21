// SPDX-License-Identifier: MIT
pragma solidity >=0.7 <0.9.0;

import './JDIToken.sol';

contract JustDoIt {

    JDIToken public jdiToken;
    enum Result {Initial, Success, Failure}

    struct Challenge {
        string key;
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
    mapping(address => mapping(string => Supporting)) public supporters;
    mapping(string => Challenge) public challenges;

    event ChallengeAdded(string key, address indexed owner, uint amountStaked, string token, uint indexed deadline);
    event SupportChallenge(address indexed supporter, string indexed key, uint amountStaked);

    constructor(address _deployer, address _jdiToken) {
        deployer = _deployer;
        jdiToken = JDIToken(_jdiToken);
    }

    function getFinalResult(string memory _key) challengeIsOver(_key) external view returns(Result) {
        return _getFinalResult(_key);
    }

    function getFees(string memory _key) challengeIsOver(_key) external view returns (uint) {
        return _getFees(_key);
    }

    function getOwnerRewards(string memory _key) challengeIsOver(_key) external view returns (uint, uint) {
        Challenge memory challenge = _getChallenge(_key);
        require(challenge.owner == msg.sender, 'You are NOT the owner');
        return _getOwnerRewards(_key, challenge);
    }

    function getSupporterRewards(string memory _key) challengeIsOver(_key) external view returns (uint, uint) {
        Challenge memory challenge = _getChallenge(_key);
        require(challenge.owner != msg.sender, 'You are the owner');
        return _getSupporterRewards(_key);
    }

    function _getChallenge(string memory _key) challengeExists(_key) internal view returns (Challenge memory) {
        return challenges[_key];
    }

    function _getFinalResult(string memory _key) internal view returns(Result) {
        Challenge memory challenge = _getChallenge(_key);
        uint votedSuccess = challenge.successes;
        uint votedFailure = challenge.failures;
        Result finalResult = Result.Initial;
        if (votedSuccess > votedFailure) {
            finalResult = Result.Success;
        } else if (votedFailure > votedSuccess) {
            finalResult = Result.Failure;
        } else if (votedSuccess == votedFailure) {
            finalResult = challenge.resultFromOwner == Result.Success ? Result.Success : Result.Failure;
        }
        return finalResult;
    }

    function _getFees(string memory _key) internal view returns (uint) {
        Challenge memory challenge = _getChallenge(_key);
        if (_getFinalResult(_key) != challenge.resultFromOwner) {
            return challenge.amountStaked;
        }
        return 0;
    }

    function _getOwnerRewards(string memory _key, Challenge memory challenge) internal view returns (uint, uint) {
        Result finalResult = _getFinalResult(_key);
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

    function _getSupporterRewards(string memory _key) internal view returns (uint , uint) {
        Result finalResult = _getFinalResult(_key);
        Result supporterResult = supporters[msg.sender][_key].result;
        if (finalResult == supporterResult) {
            // 1. Incase of a failure, should receive his staked amount.
            uint amountStaked = finalResult == Result.Failure ? supporters[msg.sender][_key].amountStaked : 0;

            // 2. Receive his proportional share from 30% of the amount staked, in JDI tokens, for supporting and voting honestly.
            Challenge memory challenge = _getChallenge(_key);
            uint totalAmount = challenge.supprtersAmountStaked;
            uint totalShare = totalAmount * 30 / 100;
            uint JDIAmount = totalShare * supporters[msg.sender][_key].amountStaked / totalAmount;

            return (amountStaked, JDIAmount);
        } else {
            // Nothing
            return (0, 0);
        }
    }

    function addChallengeETH(string memory _key, uint _deadline) external payable {
        require(msg.value > 0, 'No funds supplied');
        require(_deadline >= block.timestamp + 1 days, 'Deadline too short');
        require(challenges[_key].deadline == 0, 'Challenge already exists');
        challenges[_key]  = Challenge(_key, msg.sender, msg.value, _deadline, 0, Result.Initial, 0, 0, true, false, 0);
        emit ChallengeAdded(_key, msg.sender, msg.value, 'ETH', _deadline);
    }

    function supportChallenge(string memory _key) challengeExists(_key) external payable {
        require(msg.value > 0, 'No funds supplied');
        require(challenges[_key].owner != msg.sender, 'You are the owner');
        require(challenges[_key].deadline > block.timestamp, 'Challenge is over');
        supporters[msg.sender][_key].amountStaked += msg.value;
        challenges[_key].supprtersAmountStaked += msg.value;
        if (supporters[msg.sender][_key].amountStaked == msg.value) {
            challenges[_key].supporters++;
        }
        emit SupportChallenge(msg.sender, _key, msg.value);
    }

    function supporterReportResult(string memory _key, Result _result) canReport(_key, false) external {
        if (_result == Result.Success) {
            challenges[_key].successes++;
            supporters[msg.sender][_key].result = Result.Success;
        } else if (_result == Result.Failure) {
            challenges[_key].failures++;
            supporters[msg.sender][_key].result = Result.Failure; 
        }
    }
    
    function ownerReportResult(string memory _key, Result _result) canReport(_key, true) external {
        challenges[_key].resultFromOwner = _result;
    }

    function collectOwnerRewards(string memory _key) challengeIsOver(_key) external {
        require(challenges[_key].owner == msg.sender, 'You are NOT the owner');
        require(challenges[_key].canBeRewarded, 'No more rewards');
        (uint amountStaked, uint JDIAmount) = _getOwnerRewards(_key, challenges[_key]);

        challenges[_key].canBeRewarded = false;
        if (JDIAmount > 0) {
            jdiToken.mint(msg.sender, JDIAmount);
        }

        if (amountStaked > 0) {
            payable(msg.sender).transfer(amountStaked);
            // TODO: event
        }
    }

    function collectSupporterRewards(string memory _key) challengeIsOver(_key) external {
        require(!supporters[msg.sender][_key].gotRewards, 'No more rewards');
        require(supporters[msg.sender][_key].amountStaked > 0, 'You are not supporting this challenge');
        (uint amountStaked, uint JDIAmount) = _getSupporterRewards(_key);

        supporters[msg.sender][_key].gotRewards = true;
        if (JDIAmount > 0) {
            jdiToken.mint(msg.sender, JDIAmount);
        }

        if (amountStaked > 0) {
            payable(msg.sender).transfer(amountStaked);
            // TODO: event
        }
    }

    function collectChallengeFees(string memory _key) challengeIsOver(_key) external {
        require(!challenges[_key].gotFees, 'No more fees');
        challenges[_key].gotFees = true;
        uint amountStaked = _getFees(_key);
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

    function isChallengeExists(string memory _key) public view returns(bool) {
        return challenges[_key].deadline > 0;
    }

    function isReportTime(string memory _key) public view returns (bool) {
        return  block.timestamp > challenges[_key].deadline &&
                block.timestamp <= challenges[_key].deadline + 1 weeks;
    }

    modifier challengeExists(string memory _key) {
        require(isChallengeExists(_key), 'Challenge not found');
        _;
    }

    modifier canReport(string memory _key, bool isOwner) {
        require(isChallengeExists(_key), 'Challenge not found');
        require(isReportTime(_key), 'Not in a report time window');
        if (isOwner) {
            require(challenges[_key].owner == msg.sender, 'Not your challenge');
        } else {
            require(supporters[msg.sender][_key].amountStaked > 0, 'You are not supporting this challenge');
        }
        _;
    }

    modifier challengeIsOver(string memory _key) {
        require(isChallengeExists(_key), 'Challenge not found');
        require(block.timestamp > challenges[_key].deadline + 1 weeks, 'Challenge reporting is still going');
        _;
    }
}