//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// get Ether/USD price feed via chain.link data feed
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract CharityFund {
    AggregatorV3Interface internal priceFeed;

    // any residual fund will be sent to this address
    // for other funding purposes.
    address masterContract;
    address creator;
    // name of the campaign
    string public name;
    // the address that will receive all the fund at the end
    // of the campaign
    address public beneficiary;

    uint256 public requiredFundAmountInUSD;
    uint256 public requiredFundAmountInWei;

    uint256 public minDonationInUSD;
    uint256 public minDonationInWei;

    uint256 public conversionRate;

    // remaining time of this campaign in seconds
    uint256 public creationTime;
    uint256 public deadline;

    // whether the campaign is ended
    bool public ended;
    bool public refundToDonors;

    // save donors address to donation amount
    mapping(address => uint256) public donations;
    // save all donors address
    address[] public donors;

    event ReceivedFund(uint256 amount);
    // return the residual ether to the last donor
    event CampaignEndedSuccessfully(uint256 raisedAmount);
    event CampaignEndedFail(uint256 raisedAmount, uint256 required);
    event SendedResidualToMaster(uint256 amount);
    event NotAllDonorsWithdrawed();

    error InsufficientBalance(uint256 available, uint256 required);
    error CampaignEnded();

    modifier moreThanMinAmount() {
        conversionRate = getLatestPrice();
        requiredFundAmountInWei = USDToWei(requiredFundAmountInUSD);
        minDonationInWei = USDToWei(minDonationInUSD);
        require(
            msg.value > uint256(minDonationInWei),
            "Received value not reach minimum"
        );
        _;
    }

    modifier campaignIsActive() {
        // campaign is active if block.timestamp
        // still not reach deadline
        require(block.timestamp < deadline, "Campaign is over");
        _;
    }

    modifier campaignIsEnded() {
        require(block.timestamp > deadline, "Campaign is active");
        _;
    }

    modifier stillNotEnoughFund() {
        // check if fund has raised enough.
        require(
            address(this).balance < requiredFundAmountInWei,
            "Fund has fully raised."
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == creator, "Access denied.");
        _;
    }

    modifier onlyDonors() {
        require(
            donations[msg.sender] > 0,
            "Only donors can call this function."
        );
        _;
    }

    constructor(
        string memory _name,
        address _beneficiary,
        address _masterContract,
        uint256 _fundAmountInUSD,
        uint256 _minDonationInUSD,
        uint256 _campaignDuration
    ) {
        //Kovan testnet
        priceFeed = AggregatorV3Interface(
            0x9326BFA02ADD2366b30bacB125260Af641031331
        );

        name = _name;
        creator = msg.sender;
        beneficiary = _beneficiary;
        requiredFundAmountInUSD = _fundAmountInUSD;
        // min donation in USD
        minDonationInUSD = _minDonationInUSD;
        deadline = _campaignDuration + block.timestamp;
        creationTime = block.timestamp;
        masterContract = _masterContract;

        requiredFundAmountInWei = USDToWei(_fundAmountInUSD);
        minDonationInWei = USDToWei(_minDonationInUSD);
    }

    // you can not request for refund if you send Ether
    // via this function
    receive() external payable {
        emit ReceivedFund(msg.value);
    }

    // if someone/some contract send money via .send(),
    // .transfer(), this function will be called.
    // this function doesn't check if fund has raised
    // enough.
    fallback() external payable {
        if (msg.value > 0) {
            donations[msg.sender] += msg.value;
            donors.push(msg.sender);
            emit ReceivedFund(msg.value);
        }
    }

    function donate() public payable campaignIsActive moreThanMinAmount {
        // take the donated ether, check if the fund is enough
        // if so, refund to the last donors the residual,
        // end the campaign, send ether to the beneficiary

        donations[msg.sender] += msg.value;
        donors.push(msg.sender);
        emit ReceivedFund(msg.value);
    }

    function donorWithdraw() public campaignIsActive {
        // donors can choose to withdraw theirs donation
        // because the donor call this function, he/she will have
        // to pay for the gas fee.
        // this function is for withdraw money when campaign is active.
        uint256 amount = donations[msg.sender];
        require(
            donations[msg.sender] > 0,
            "You already withdrawed or you didn't donate to this campaign."
        );
        // Reentrancy attack is too old
        donations[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function getRemainingTime() public view returns (uint256) {
        // return the remaining time of this campagn in hours
        if (block.timestamp < deadline) {
            return deadline - block.timestamp;
        }
        return 0;
    }

    function getCampaignBalance() public view returns (uint256) {
        // return the raised fund in wei
        return address(this).balance;
    }

    function USDToWei(uint256 USDAmount) internal returns (uint256) {
        // convert USDAmount to wei, get conversion rate from chain.link
        conversionRate = getLatestPrice();
        uint256 oneDollarPrice = 10**18 / (conversionRate / (10**26));
        return USDAmount * oneDollarPrice;
    }

    function getNumDonors() public view returns (uint256) {
        // return the number of donors to this contract
        return donors.length;
    }

    function getLatestPrice() internal view returns (uint256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // multiply with 10**18 for easy converse from dollar to wei
        // 1 dollar equal 1*10**26 of the returned price
        return uint256(price * 10**18);
    }

    function endCampaign() public campaignIsEnded onlyDonors {
        // it is not decentralized anymore if only the creator
        // of this contract can end the campaign and send money to
        // beneficiary when reach deadline. So every donors can call this
        // function to send money to beneficiary when it reach deadline.

        // end the campaign if reach deadline
        // if raised enough money, send it to the beneficiary
        // if not enough money, refund to all donors.
        // send the required fund amount to beneficiary
        // send all the residual fund to masterContract

        // beneficiary should be a trusted account
        ended = true;
        uint256 balance = address(this).balance;
        if (balance >= requiredFundAmountInWei) {
            payable(beneficiary).transfer(requiredFundAmountInWei);
            uint256 residual = address(this).balance;
            emit CampaignEndedSuccessfully(balance);
            if (residual > 0) {
                payable(masterContract).transfer(residual);
                emit SendedResidualToMaster(residual);
            } else {
                // set refundToDonors = true will allow all donors
                // to withdraw their money.
                refundToDonors = true;
                emit CampaignEndedFail(
                    address(this).balance,
                    requiredFundAmountInWei
                );
            }
        }
    }

    function withdraw() public campaignIsEnded onlyDonors {
        // this function is used to withdraw when campaign
        // is ended and not raise enough money.
        require(
            refundToDonors,
            "Fund was sent to beneficiary, can not refund."
        );
        uint256 refundAmount = donations[msg.sender];
        if (refundAmount > 0) {
            // Reentrancy attack is too old
            donations[msg.sender] = 0;
        }
    }

    function endContract() public onlyOwner {
        // can only destroy this contract if
        // either fund was raised successfully and was sent to
        // the beneficiary,
        // or fund raised not enough and all donors has withdrawed
        // their money.
        // any residual will be sent to master.
        bool allowDestroy = true;
        for (uint256 i = 0; i < donors.length; i++) {
            if (donations[donors[i]] > 0) {
                allowDestroy = false;
                break;
            }
        }

        if (allowDestroy) {
            selfdestruct(payable(masterContract));
        } else {
            emit NotAllDonorsWithdrawed();
        }
    }
}
// 9999997000000000 2628811777076760
