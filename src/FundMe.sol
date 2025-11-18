// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error FundMe__NotOwner();

contract FundMe {

    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5e18;

    address[] private s_funders;
    mapping (address funder => uint256 amountFunded) private s_addressToAmountFunded;

    address private immutable i_owner;

    AggregatorV3Interface private immutable i_priceFeed;

    constructor(address priceFeed) {
        i_owner = msg.sender;
        i_priceFeed = AggregatorV3Interface(priceFeed);
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {revert FundMe__NotOwner();}
        //require(msg.sender == i_owner, "Must be the owner");
        _;
    }

    function fund() public payable {
        require(msg.value.getConversionRate(i_priceFeed) >= MINIMUM_USD, "Did not send enough");
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] += msg.value;
    }

    function getVersion() public view returns (uint256) {
        return i_priceFeed.version();
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 lenFunders = s_funders.length;
        for (uint funderIndex = 0; funderIndex < lenFunders; funderIndex++) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);

        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    function withdraw() public onlyOwner {

        for(uint i = 0; i < s_funders.length; i++) {
            address funder = s_funders[i];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);

        //transfer
        // payable(msg.sender).transfer(address(this).balance);
        // //send
        // bool sent = payable(msg.sender).send(address(this).balance);
        // require(sent, "Send failed");
        // //call
        (bool callSuccess,) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }

    //What happens if someone sends ETH to the contract without calling fund()?
    receive() external payable {
        fund();
    }

    fallback() external payable {
        fund();
    }

    /**
     * View / pure funcs
     */

    function getAddressToAmountFunded(address fundingAddress) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}