// SPDX-License-Identifier: MIT
pragma solidity >=0.7 <0.9.0;

import './JDIToken.sol';

contract JustDoIt_V3_0_1 {

    JDIToken public jdiToken;
    enum Result {Initial, Success, Failure}

    struct Supporting {
        uint amountStaked;
        bool gotRewards;
        Result result;
    }

    struct Challenge {
        bytes32 id;
        address owner;
        uint amountStaked;
        uint deadline;
        uint supprtersAmountStaked;
        Result resultFromOwner;
        string ownerReportPath;
        uint successes;
        uint failures;
        bool canBeRewarded;
        bool gotFees;
        mapping(address => Supporting) supporters;
    }

    address public deployer;
    uint public totalFeesAmount;
    mapping(bytes32 => Challenge) public challenges;

    event ChallengeAdded(bytes32 id, address indexed owner, string name, uint amountStaked, string token, uint indexed deadline);
    event SupportChallenge(address indexed supporter, bytes32 indexed id, uint amountStaked);
    event OwnerReportResult(bytes32 id, address indexed owner, Result result, string path);
    event SupporterReportResult(bytes32 id, address indexed supporter, Result result);

    function initialize(address _deployer, address _jdiToken) public {
        deployer = _deployer;
        jdiToken = JDIToken(_jdiToken);
    }

    function getFinalResult(bytes32  _id) challengeIsOver(_id) external view returns(Result) {
        return _getFinalResult(_id);
    }

    function getFees(bytes32 _id) challengeIsOver(_id) external view returns (uint) {
        return _getFees(_id);
    }

    function getOwnerRewards(bytes32 _id) challengeIsOver(_id) external view returns (uint, uint) {
        Challenge storage challenge = _getChallenge(_id);
        require(challenge.owner == msg.sender, 'You are NOT the owner');
        return _getOwnerRewards(_id, challenge);
    }

    function getSupporterRewards(bytes32 _id) challengeIsOver(_id) external view returns (uint, uint) {
        require(_getChallenge(_id).owner != msg.sender, 'You are the owner');
        return _getSupporterRewards(_id);
    }

    function getChallengeSupporter(bytes32 _id) external view returns (Supporting memory) {
        return challenges[_id].supporters[msg.sender];
    }

    function _getChallenge(bytes32 _id) challengeExists(_id) internal view returns (Challenge storage) {
        return challenges[_id];
    }

    function _getFinalResult(bytes32 _id) internal view returns(Result) {
        Challenge storage challenge = _getChallenge(_id);
        uint votedSuccess = challenge.successes;
        uint votedFailure = challenge.failures;
        Result finalResult = Result.Failure;
        if (challenge.resultFromOwner == Result.Success && votedSuccess >= votedFailure) {
            finalResult = Result.Success;
        }
        return finalResult;
    }

    function _getFees(bytes32 _id) internal view returns (uint) {
        if (_getFinalResult(_id) != _getChallenge(_id).resultFromOwner) {
            return _getChallenge(_id).amountStaked;
        }
        return 0;
    }

    function _getOwnerRewards(bytes32 _id, Challenge storage challenge) internal view returns (uint, uint) {
        Result finalResult = _getFinalResult(_id);
        Result ownerResult = challenge.resultFromOwner;
        if (finalResult == ownerResult) {
            // 1. If Success, receive his original staking + all supporters staking amounts.
            uint amountStaked = finalResult == Result.Success ? challenge.amountStaked + challenge.supprtersAmountStaked: 0;

            // 2. Receive *1 of the staked amount in JDI tokens for trying to or completing the challenge.
            uint JDIAmount = challenge.amountStaked + challenge.supprtersAmountStaked;
            return (amountStaked, JDIAmount);
        } else {
            // Nothing
            return (0, 0);
        }
    }

    function _getSupporterRewards(bytes32 _id) internal view returns (uint , uint) {
        Supporting memory supporter = _getChallenge(_id).supporters[msg.sender];
        Result finalResult = _getFinalResult(_id);
        if (finalResult == supporter.result || challenges[_id].resultFromOwner != Result.Success) {
            // 1. Incase of a failure, should receive his staked amount.
            uint amountStaked = finalResult == Result.Failure ? supporter.amountStaked : 0;

            // 2. Receive his proportional share from *10 of the amount staked, in JDI tokens, for supporting and voting honestly.
            uint totalAmount = _getChallenge(_id).supprtersAmountStaked;
            uint totalShare = totalAmount * 10;
            uint JDIAmount = totalShare * supporter.amountStaked / totalAmount;

            return (amountStaked, JDIAmount);
        } else {
            // Nothing
            return (0, 0);
        }
    }

    function addChallengeETH(bytes32 _id, string calldata _name, uint _deadline) external payable {
        require(msg.value > 0, 'No funds supplied');
        require(_deadline >= block.timestamp + 1 days, 'Deadline too short');
        require(challenges[_id].deadline == 0, 'Challenge already exists');
        Challenge storage challenge = challenges[_id];
        challenge.id = _id;
        challenge.owner = msg.sender;
        challenge.amountStaked = msg.value;
        challenge.deadline = _deadline;
        challenge.canBeRewarded = true;
        challenge.gotFees = false;
        emit ChallengeAdded(_id, msg.sender, _name, msg.value, 'ETH', _deadline);
    }

    function supportChallenge(bytes32 _id) challengeExists(_id) external payable {
        require(msg.value > 0, 'No funds supplied');
        Challenge storage challenge = challenges[_id];
        require(challenge.owner != msg.sender, 'You are the owner');
        require(challenge.deadline > block.timestamp, 'Challenge deadline is over');
        challenge.supporters[msg.sender] = Supporting({result: Result.Initial, amountStaked: msg.value, gotRewards: false});
        challenge.supprtersAmountStaked += msg.value;
        emit SupportChallenge(msg.sender, _id, msg.value);
    }

    function supporterReportResult(bytes32 _id, Result _result) canReport(_id, false) external {
        require(_result != Result.Initial, 'Can only report Success or Failure');
        _result == Result.Success ? challenges[_id].successes++ : challenges[_id].failures++;
        _getChallenge(_id).supporters[msg.sender].result = _result; 
        emit SupporterReportResult(_id, msg.sender, _result);
    }
    
    function ownerReportResult(bytes32 _id, Result _result, string calldata _path) canReport(_id, true) external {
        require(_result != Result.Initial, 'Can only report Success or Failure');
        challenges[_id].resultFromOwner = _result;
        challenges[_id].ownerReportPath = _path;
        emit OwnerReportResult(_id, msg.sender, _result, _path);
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
        Supporting storage supporter = _getChallenge(_id).supporters[msg.sender];
        require(!supporter.gotRewards, 'No more rewards');
        require(supporter.amountStaked > 0, 'You are not supporting this challenge');
        (uint amountStaked, uint JDIAmount) = _getSupporterRewards(_id);

        supporter.gotRewards = true;
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

    function _isChallengeOver(bytes32 _id) internal view returns(bool) {
        return block.timestamp > challenges[_id].deadline + 1 weeks 
        || challenges[_id].resultFromOwner == Result.Failure 
        || (block.timestamp > challenges[_id].deadline + 2 days && challenges[_id].resultFromOwner != Result.Success);
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
            require(challenges[_id].resultFromOwner == Result.Initial, 'Owner already reported');
        } else {
            require(_getChallenge(_id).supporters[msg.sender].amountStaked > 0, 'You are not supporting this challenge');
            require(_getChallenge(_id).supporters[msg.sender].result == Result.Initial, 'Supporter already voted');
            require(challenges[_id].resultFromOwner == Result.Success, 'Owner did not report any result yet or reported failure');
        }
        _;
    }

    modifier challengeIsOver(bytes32 _id) {
        require(_isChallengeExists(_id), 'Challenge not found');
        require(_isChallengeOver(_id), 'Challenge reporting is still going');
        _;
    }

    function getVersion() external pure returns(string memory) {
        return '3.0.1';
    }
}