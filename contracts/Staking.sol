// SPDX-License-Identifier: MIT

// stake: Lock tokens into our smart contract
// withdraw: Unlock tokens and pull out of the smart contract
// claimReward: Users get their reward tokens
//      What's good reward mechanism?
//      What's some good reward math?

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error Staking_TransferFailed();
error Staking_NeedsMoreThanZero();

contract Staking {
    IERC20 public s_stakingToken;
    IERC20 public s_rewardToken;

    uint256 public s_totalSupply;
    uint256 public s_rewardPerTokenStored;
    uint256 public s_lastUpdateTime;
    uint256 public constant REWARD_RATE = 100;

    // address -> how much they staked
    mapping(address => uint256) public s_balances; 

    // a mapping of how much each address has been paid
    mapping(address => uint256) public s_userRewardPerTokenPaid;

    // mapping of how much rewards each address has
    mapping(address => uint256) public s_rewards;

    modifier updateReward(address account) {
        // How much is the reward per token?
        // Last timestamp
        // 12 - 1, user earned X tokens
        s_rewardPerTokenStored = rewardPerToken();
        s_lastUpdateTime = block.timestamp;
        s_rewards[account] = earned(account);
        s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0){
            revert Staking_NeedsMoreThanZero();
        }
        _;
    }

    constructor(address _stakingToken, address _rewardToken) {
        s_stakingToken = IERC20(_stakingToken);
        s_rewardToken = IERC20(_rewardToken);
    }

    function earned(address account) public view returns (uint256) {
        uint256 currentBalance = s_balances[account];
        // how much they have been paid already
        uint256 amountPaid = s_userRewardPerTokenPaid[account]; 
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 pastRewards = s_rewards[account];

        uint256 _earned = ((currentBalance * (currentRewardPerToken - amountPaid))/1e18) + pastRewards;
        return _earned;
    }

    function rewardPerToken() public view returns(uint256) {
        if (s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        }
        return s_rewardPerTokenStored + (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) / s_totalSupply);
    }

    // One specific ERC token:
    function stake(uint256 _amount) external updateReward(msg.sender) moreThanZero(_amount){
        // keep track of how much the user has staked
        // keep track of how much we have total
        // transfer token to this contract
        s_balances[msg.sender] = s_balances[msg.sender]  + _amount;
        s_totalSupply = s_totalSupply + _amount;
        // emit event (skipped)
        bool success = s_stakingToken.transferFrom(msg.sender, address(this), _amount);
        if(!success) {
            revert Staking_TransferFailed(); 
        }
    }

    // Withdrawing tokens
    function withdraw(uint256 _amount) external updateReward(msg.sender) moreThanZero(_amount){
        s_balances[msg.sender] = s_balances[msg.sender]  - _amount;
        s_totalSupply = s_totalSupply - _amount;
        bool success = s_stakingToken.transfer(msg.sender, _amount);
        if(!success) {
           revert Staking_TransferFailed(); 
        }
    }

    function claimReward() external updateReward(msg.sender){
        uint256 rewards = s_rewards[msg.sender];
        bool success = s_rewardToken.transfer(msg.sender, rewards);
        if (!success){
            revert Staking_TransferFailed(); 
        }
        // How much reward do they get
        // Contract is going to emit X tokens per second and disperse them to all stakers
        // 100 rewards per second

        // staked: 50 tokens, 20 tokens, 30 tokens
        // rewards: 50 reward tokens, 20 reward tokens, 30 reward tokens

        // staked: 100, 50, 20, 30 (total = 200)
        // rewards: 50, 25, 10, 15

        // 1:1 reward will bankrupt protocol!

        // 5 seconds, 1 person had 100 token staked = reward 500 tokens
        // 6 seconds, 2 person have 100 tokens staked each:
        //      Person 1: 550
        //      Person 2: 50
        // ok between seconds 1 and 5, person 1 got 500 tokens
        // ok at second 6 on, person 2 gets 50 tokens now
    }
}
