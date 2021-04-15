// SPDX-License-Identifier: MIT
pragma solidity >=0.7 <0.9.0;

import './JDIToken.sol';

contract JustDoIt {

    JDIToken public jdiToken;
    enum Result {Initial, Success, Failure}

    struct Challenge {
        string key;
        uint id;
        address owner;
        uint amountStaked;
        uint deadLine;
        uint supprtersAmountStaked;
        Result resultFromOwner;
        uint successes;
        uint failures;
        bool canBeRewarded;
        bool gotFees;
        address[] supporters;
        address[] referees;
    }

    struct Supporter {
        uint amountStaked;
        bool gotRewards;
        Result result;
    }

    address public deployer;
    Challenge[] public challenges;
    mapping(string => uint) challengeIndexByKey;
    mapping(address => mapping(string => Supporter)) supporters;
    mapping(address => string[]) challengeByAccount;
    uint totalFeesAmount = 10;

    constructor(address _deployer, address _jdiToken) {
        deployer = _deployer;
        jdiToken = JDIToken(_jdiToken);
    }

    function getChallenge(string memory _key) challengeExists(_key) external view returns (Challenge memory) {
        return _getChallenge(_key);
    }
    
    function _getChallenge(string memory _key) challengeExists(_key) internal view returns (Challenge memory) {
        return challenges[challengeIndexByKey[_key] - 1];
    }

    function getChallenges() external view returns(Challenge[] memory) {
        return challenges;
    }
    
    function getChallengesByAccount(address _supporter) external view returns (string[] memory) {
        return challengeByAccount[_supporter];
    }
    
    function getFinalResult(string memory _key) challengeIsOver(_key) external view returns(Result) {
        return _getFinalResult(_key);
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

    function getFees(string memory _key) challengeIsOver(_key) external view returns (uint) {
        return _getFees(_key);
    }

    function _getFees(string memory _key) internal view returns (uint) {
        Challenge memory challenge = _getChallenge(_key);
        Result finalResult = _getFinalResult(_key);
        Result ownerResult = challenge.resultFromOwner;
        if (finalResult != ownerResult) {
            return challenge.amountStaked;
        }
        return 0;
    }

    function getOwnerRewards(string memory _key) challengeIsOver(_key) external view returns (uint, uint) {
        Challenge memory challenge = _getChallenge(_key);
        require(challenge.owner == msg.sender, 'You are NOT the owner');
        return _getOwnerRewards(_key, challenge);
    }

    function _getOwnerRewards(string memory _key, Challenge memory challenge) internal view returns (uint, uint) {
        Result finalResult = _getFinalResult(_key);
        Result ownerResult = challenge.resultFromOwner;
        if (finalResult == ownerResult) {
            // If Success, Should receive his original staking + all supporters staking amounts.
            uint amountStaked = finalResult == Result.Success ? challenge.amountStaked + challenge.supprtersAmountStaked: 0;
            // TODO: should receive JDI tokens for trying or completing the challenge succefully.
            uint JDIAmount = (challenge.amountStaked + challenge.supprtersAmountStaked) / 100;
            return (amountStaked, JDIAmount);
        } else {
            // Nothing
            return (0, 0);
        }
    }

    function getSupporterRewards(string memory _key) challengeIsOver(_key) external view returns (uint, uint) {
        Challenge memory challenge = _getChallenge(_key);
        require(challenge.owner != msg.sender, 'You are the owner');
        return _getSupporterRewards(_key);
    }


    function _getSupporterRewards(string memory _key) internal view returns (uint , uint) {
        Result finalResult = _getFinalResult(_key);
        Result supporterResult = supporters[msg.sender][_key].result;
        if (finalResult == supporterResult) {
            // Incase of a failure, should receive his amount staked back.
            uint amountStaked = finalResult == Result.Failure ? supporters[msg.sender][_key].amountStaked : 0;
            // TODO: should receive JDI tokens for supporting and voting honestly.
            Challenge memory challenge = _getChallenge(_key);
            uint totalAmount = challenge.supprtersAmountStaked;
            uint totalShare = totalAmount * 30 / 100;
            uint supporterShare = supporters[msg.sender][_key].amountStaked / totalAmount;
            uint JDIAmount = totalShare * supporterShare;

            return (amountStaked, JDIAmount);
        } else {
            // Nothing
            return (0, 0);
        }
    }

    function addChallengeETH(string memory _key, uint _deadLine) external payable {
        require(msg.value > 0, 'No funds supplied');
        require(_deadLine >= block.timestamp + 1 days, 'Deadline too short');
        require(challengeIndexByKey[_key] == 0, 'Challenge already exists');
        address[] memory initial;
        Challenge memory challenge = Challenge(_key, challenges.length, msg.sender, msg.value, _deadLine, 0, Result.Initial, 0, 0, true, false, initial, initial);
        challenges.push(challenge);
        challengeIndexByKey[_key] = challenges.length;
        challengeByAccount[msg.sender].push(_key);
    }

    function supportChallenge(string memory _key) challengeExists(_key) external payable {
        require(msg.value > 0, 'No funds supplied');
        uint index = challengeIndexByKey[_key];
        require(challenges[index - 1].owner != msg.sender, 'You are the owner');
        require(challenges[index - 1].deadLine > block.timestamp, 'Challenge is over');
        supporters[msg.sender][_key].amountStaked += msg.value;
        challenges[index - 1].supprtersAmountStaked += msg.value;
        if (supporters[msg.sender][_key].amountStaked == msg.value) {
            challenges[index - 1].supporters.push(msg.sender);
            challengeByAccount[msg.sender].push(_key);
        }
    }

    function supporterReportResult(string memory _key, Result _result) canReport(_key, false) external {
        uint index = challengeIndexByKey[_key];
        if (_result == Result.Success) {
            challenges[index - 1].successes++;
            supporters[msg.sender][_key].result = Result.Success;
        } else if (_result == Result.Failure) {
            challenges[index - 1].failures++;
            supporters[msg.sender][_key].result = Result.Failure; 
        }
    }
    
    function ownerReportResult(string memory _key, Result _result) canReport(_key, true) external {
        uint index = challengeIndexByKey[_key];
        challenges[index - 1].resultFromOwner = _result;
    }

    function collectOwnerRewards(string memory _key) challengeIsOver(_key) external {
        uint index = challengeIndexByKey[_key];
        require(challenges[index - 1].owner == msg.sender, 'You are NOT the owner');
        require(challenges[index - 1].canBeRewarded, 'No more rewards');
        (uint amountStaked, uint JDIAmount) = _getOwnerRewards(_key, challenges[index - 1]);

        challenges[index - 1].canBeRewarded = false;
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
        uint index = challengeIndexByKey[_key];
        require(!challenges[index - 1].gotFees, 'No more fees');
        uint amountStaked = _getFees(_key);
        totalFeesAmount += amountStaked;
        challenges[index - 1].gotFees = true;
        jdiToken.mint(address(this), amountStaked * 2 / 1000); // 0.2%
    }

    function collectFees() external {
        require(msg.sender == deployer, 'Only deployer');
        require(totalFeesAmount > 0, 'No Fees');
        uint total = totalFeesAmount;
        totalFeesAmount = 0;
        payable(deployer).transfer(total);
        uint balance = jdiToken.balanceOf(address(this));
        jdiToken.burn(address(this), balance * 10 / 100);
    }

    function isChallengeExists(string memory _key) public view returns(bool) {
        uint index = challengeIndexByKey[_key];
        return index > 0;
    }

    function isReportTime(string memory _key) public view returns (bool) {
        uint index = challengeIndexByKey[_key];
        return  block.timestamp > challenges[index - 1].deadLine &&
                block.timestamp <= challenges[index - 1].deadLine + 1 weeks;
    }

    modifier challengeExists(string memory _key) {
        require(isChallengeExists(_key), 'Challenge not found');
        _;
    }

    modifier canReport(string memory _key, bool isOwner) {
        require(isChallengeExists(_key), 'Challenge not found');
        require(isReportTime(_key), 'Not in a report time window');
        if (isOwner) {
            require(challenges[challengeIndexByKey[_key] - 1].owner == msg.sender, 'Not your challenge');
        } else {
            require(supporters[msg.sender][_key].amountStaked > 0, 'You are not supporting this challenge');
        }
        _;
    }

    modifier challengeIsOver(string memory _key) {
        require(isChallengeExists(_key), 'Challenge not found');
        require(challenges[challengeIndexByKey[_key] - 1].deadLine > block.timestamp + 1 weeks, 'Challenge reporting is still going');
        _;
    }
}