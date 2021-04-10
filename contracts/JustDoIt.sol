// SPDX-License-Identifier: MIT
pragma solidity >=0.7 <0.9.0;

contract JustDoIt {

    struct Challenge {
        string key;
        uint id;
        address owner;
        uint amountStaked;
        uint supprtersAmountStaked;
        uint deadLine;
        address[] supporters;
    }
    address public deployer;
    Challenge[] public challenges;
    mapping(string => uint) public challengeIndexByKey;
    mapping(address => mapping(string => uint)) supporters;

    constructor(address _deployer) {
        deployer = _deployer;
    }

    function addChallengeETH(string memory _key, uint _deadLine) external payable {
        require(msg.value > 0, 'No funds supplied');
        require(_deadLine >= block.timestamp + 1 days, 'Deadline too short');
        require(challengeIndexByKey[_key] == 0, 'Challenge already exists');
        address[] memory initial;
        Challenge memory challenge = Challenge(_key, challenges.length, msg.sender, msg.value, _deadLine, 0, initial);
        challenges.push(challenge);
        challengeIndexByKey[_key] = challenges.length;
    }

    function getChallenges() external view returns(Challenge[] memory) {
        return challenges;
    }

    function supportChallenge(string memory _key) external payable {
        require(msg.value > 0, 'No funds supplied');
        uint index = challengeIndexByKey[_key];
        require(index > 0, 'Challenge not found');
        require(challenges[index -1].deadLine > block.timestamp, 'Challenge is over');
        supporters[msg.sender][_key] += msg.value;
        challenges[index -1].supprtersAmountStaked += msg.value;
        challenges[index -1].supporters.push(msg.sender);
        // TODO: Reward supporter a Support Token
    }
    
    function distributeChallengeFunds(string memory _key) external {

    }
}