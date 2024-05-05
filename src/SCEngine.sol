//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {StableCoin} from "./StableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title SCEngine
 * @author Khaled Ashraf
 * 
 * Engine is designed to have the coin maintain its peg to one dollar.
 * Properties:
 * - Algorithmic
 * - Crypto Collateral
 * - Gold Pegged
 * @notice This contract has the logic of minting and burning coins.
 * @notice This contract also includes depositing and withrawing collateral.
 * 
 * 
 * @notice VERY IMPORTANT: Overcollaterlization is essential for the coin to maintain its peg. 
 * At no point in time should the value of all collateral be less than or equal to the value of all SC.
 */

contract SCEngine{
    //ERRORS
    error SCEngine_MustBeMoreThanZero();
    error SCEngine_TokenAndPriceFeedLengthMismatch();
    error SCEngine_TokenNotSupported();
    error SCEngine_TransferFailed();
    error SCEngine_BreaksHealthFactor(uint256 healthFactor);
    error SCEngine_MintFailed();
    error SCEngine_HealthFactorOk();
    error SCEngine_HealthFactorNotImproved();

    // STATE VARIABLES

    uint256 private constant LiquidationThreshold = 50; // Overcollaterlization ratio

    mapping(address token => address pricefeed) public priceFeed; // Map the token to its price feed
    mapping(address user => mapping(address token => uint256 amount)) private collateralDeposited; // Map the user to the amount of collateral they have deposited
    mapping(address user => uint256 amountMinted) private scMinted; // Map the user to the amount of SC they have minted
    address[] private collateralTokens; // Array to store the addresses of the collateral tokens

    StableCoin private immutable i_sc; // Create an instance of the StableCoin contract that is immutable


    // EVENTS
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount); // Event to show that collateral has been deposited
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount); // Event to show that collateral has been redeemed

    // MODIFIERS
    modifier moreThanZero(uint256 amount){ // Modifier to check if the amount is more than zero
        if(amount == 0){
            revert SCEngine_MustBeMoreThanZero();
        }
        _;
    }


    modifier allowedCollateral(address token){ // Modifier to check if the token is supported
        if(priceFeed[token] == address(0)){
            revert SCEngine_TokenNotSupported();
        }
        _;
    }


    // Constructor function that takes in the addresses of the tokens and their price feeds and the address of the StableCoin contract
    constructor(address[] memory tokenAddress, address[] memory priceFeedAddresses, address scAddress){
        if(tokenAddress.length != priceFeedAddresses.length){ // Check if the length of the token address array is equal to the length of the price feed address array
            revert SCEngine_TokenAndPriceFeedLengthMismatch();
        }

        for(uint256 i = 0; i < tokenAddress.length; i++){ // Loop through the token address array and map the token to its price feed
            priceFeed[tokenAddress[i]] = priceFeedAddresses[i];
            collateralTokens.push(tokenAddress[i]); // Add the token to the collateral tokens array
        }
        i_sc = StableCoin(scAddress); // Create an instance of the StableCoin contract
    }

    // EXTERNAL FUNCTIONS

    /**
     * @param collateralAddress, the address of the cryptocurrency used as collateral
     * @param amountCollateral, the amount of the collateral to deposit.
     * @param amountSCtoMint, the amount of SC to mint
     * 
     * The function is used to deposit collateral into the system and mint SC
     */

    function depositCollateralAndMintSC(address collateralAddress, uint256 amountCollateral, uint256 amountSCtoMint) external{
        depositCollateral(collateralAddress, amountCollateral); // Deposit the collateral
        mintSC(amountSCtoMint); // Mint the SC
    }


    /* 
     * @param token, the address of the cryptocurrency used as collateral
     * @param amount, the amount of the collateral to deposit.
     * 
     * The function is used to deposit collateral into the system.
     */
    function depositCollateral(address token, uint256 amount) public moreThanZero(amount) allowedCollateral(token){
        collateralDeposited[msg.sender][token] += amount; // Add the amount of collateral to the user's balance
        emit CollateralDeposited(msg.sender, token, amount); // Emit an event to show that the collateral has been deposited.
        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount); // Transfer the collateral from the user to the contract
        if (!success){
            revert SCEngine_TransferFailed();
        }
    }


    /**
     * @param collateralAddress, the address of the cryptocurrency used as collateral
     * @param amountCollateral, the amount of the collateral to redeem.
     * @param amountSC, the amount of SC to redeem
     * 
     * The function is used to redeem collateral and burn SC
     * SC must be burned first before collateral is redeemed.
     */
    function redeemCollateralForSC(address collateralAddress, uint256 amountCollateral, uint256 amountSC) external{
        burnSC(amountSC); // Burn the SC
        redeemCollateral(collateralAddress, amountCollateral); // Redeem the collateral

    }

    // Health Factor must be > 1 after collateral is pulled.
    function redeemCollateral(address collateralAddress, uint256 amount) public moreThanZero(amount) allowedCollateral(collateralAddress){
        _redeemCollateral(collateralAddress, amount, msg.sender, msg.sender); // Redeem the collateral
        revertBrokenHealthFactor(msg.sender); // Check if the user's health factor is broken after transferring the collateral
    }



    /**
     * 
     * @param amount the amount of SC to mint
     * @notice Must have more collateral value than minimum threshold
     */
    function mintSC(uint256 amount) public moreThanZero(amount){

        scMinted[msg.sender] += amount; // Add the amount of SC minted to the user's balance
        // If too much is minted then revert
        revertBrokenHealthFactor(msg.sender); // Check if the user's health factor is broken
        bool minted = i_sc.mint(msg.sender, amount); // Mint the SC
        if(!minted){
            revert SCEngine_MintFailed(); // If the SC is not minted, revert
        }

    }
    // We don't need to check health factor here because the user is burning SC
    function burnSC(uint256 amount) public moreThanZero(amount){
        _burnSC(amount, msg.sender, msg.sender); // Burn the SC
    }



    /**
     * @notice Liquidate the user's position
     * @notice Liquidation is triggered when the user's health factor is less than or equal to 1
     * @notice Liquidation is the process of selling the user's collateral to pay off their debt
     * 
     * @notice The liquidator will receive a reward for liquidating the user
     * The process is as follows:
     * - When the health factor of any person falls below the the threshold, someone else can liquidate them
     * - The liquidator basically buys out their debt and takes their collateral.
     * - This results in the liquidator getting the collateral and the user's debt being paid off
     * - For example, say the user has 1000 USD of SC and 2000 USD worth of collateral.
     *      - If the collateral falls to 1500 USD, the user can be liquidated.
     *      - The person that liquidated the user would have to pay for the 1000 SC and would get the 1500 USD worth of collateral
     *      - This results in a 500 USD profit for the liquidator
     * - You can also partially liquidate a user
     * 
     * @param collateral the address of the collateral token
     * @param user the address of the user to liquidate
     * @param debtToPay the amount of debt to pay
     * 
     * @notice This system only works if there is overcollaterliazation by roughly 200%.
     * @notice A known problem is that if the protocol is 100% or less collateralized, since this would mean that there is no incentive to liquidate.
     * 
     * 
     */


    function liquidate(address collateral, address user, uint256 debtToPay) external moreThanZero(debtToPay) {
        // Check Health Factor (Should he be liquidated?)
        uint256 healthFactorBefore = healthFactor(user);
        if(healthFactorBefore >= 1e18){
            revert SCEngine_HealthFactorOk();
        }

        // Burn the SC and take their collateral
        uint256 tokenAmountFromDebt = getTokenAmountFromUSD(collateral, debtToPay); // Get the amount of collateral to take from the debt

        // To fix the problem mentioned above, we can give the liquidator a 10% bonus
        uint256 bonusCollateral = (tokenAmountFromDebt * 10) / 100; // Calculate the bonus collateral
        uint256 totalCollateralToTake = tokenAmountFromDebt + bonusCollateral; // Calculate the total collateral to take
        _redeemCollateral(collateral, totalCollateralToTake, user, msg.sender); // Redeem the collateral

        // Burn the SC

        _burnSC(debtToPay, user, msg.sender); // Burn the SC

        uint256 healthFactorAfter = healthFactor(user);
        if(healthFactorAfter <= healthFactorBefore){
            revert SCEngine_HealthFactorNotImproved();
        }

        revertBrokenHealthFactor(msg.sender); // Check if the liquidator's health factor is broken


    }

// INTERNAL FUNCTIONS

function _burnSC(uint256 amount, address onBehalfOf, address scFrom) private{
    scMinted[onBehalfOf] -= amount; // Subtract the amount of SC from the user's balance
        bool success = i_sc.transferFrom(scFrom, address(this), amount); // Burn the SC
        if(!success){
            revert SCEngine_TransferFailed(); // If the SC is not burned, revert
        }
        i_sc.burn(amount); // Burn the SC
}


function _redeemCollateral(address collateralAddress, uint256 amount, address from, address to) private {
    collateralDeposited[from][collateralAddress] -= amount; // Subtract the amount of collateral from the user's balance
        emit CollateralRedeemed(from, to, collateralAddress, amount); // Emit an event to show that the collateral has been redeemed
        bool success = IERC20(collateralAddress).transfer(from, amount); // Transfer the collateral from the contract to the user
        if(!success){
            revert SCEngine_TransferFailed();
        }
}

function getTotals(address user) private view returns(uint256 totalSCMinted, uint256 totalCollateralValue){
    totalSCMinted = scMinted[user]; // Get the total amount of SC minted by the user
    totalCollateralValue = getAccountCollateralValue(user); // Get the total value of the collateral deposited by the user
}
    // Public


/**
 * 
 * @param user the address of the user
 * @return the health factor of the user
 * @notice Health factor is the ratio of the value of the collateral to the value of the SC minted
 * Returns how close the user is to being liquidated
 * If the user has a health factor of 1, they are at the liquidation threshold
 
 */
function healthFactor(address user) private view returns(uint256){
    // To do this we need two things: Total SC Minted and total *VALUE* of collateral.
    (uint256 totalSCMinted, uint256 totalCollateralValue) = getTotals(user);
    return _calculateHealthFactor(totalSCMinted, totalCollateralValue); // Return the health factor
}

function _calculateHealthFactor(uint256 totalSCMinted, uint256 totalCollateralValue) internal pure returns(uint256){
    if(totalSCMinted == 0){
        return type(uint256).max; // If the total SC minted is zero, return the maximum value of a uint256
    }
    return ((((totalCollateralValue * 50) / 100) * 1e18)/ totalSCMinted); // Calculate the health factor
}


function revertBrokenHealthFactor(address user) internal view{
    // First check health factor -> do they have enough collateral?
    // Revert if not
    uint256 userHealthFactor = healthFactor(user);
    if(userHealthFactor <= 1e18){ // If the user's health factor is less than or equal to 1, revert
        revert SCEngine_BreaksHealthFactor(userHealthFactor);
    }

}





// PUBLIC and EXTERNAL FUNCTIONS

function getTokenAmountFromUSD(address token, uint256 usdAmountInWei) public view returns (uint256){
    // Get price of token
    AggregatorV3Interface priceFeeds = AggregatorV3Interface(priceFeed[token]);
    (,int price,,,) = priceFeeds.latestRoundData();
    // 8 decimal places for both BTC and ETH to USD
    return (usdAmountInWei * 1e18) / (uint256(price) * 1e10);
}

function getAccountCollateralValue(address user) public view returns(uint256 totalCollateralValue){
    // loop through each collateral token and get the amount they have deposited, then map it to the price feed and get the value
    for(uint256 i = 0; i < collateralTokens.length; i++){
        address token = collateralTokens[i];
        uint256 amount = collateralDeposited[user][token];
        totalCollateralValue +=getUSDValue(token, amount);
    }
    return totalCollateralValue;
}

function getUSDValue(address token, uint256 amount) public view returns(uint256){
    AggregatorV3Interface priceFeeds = AggregatorV3Interface(priceFeed[token]);
    (,int price,,,) = priceFeeds.latestRoundData();
    // 8 decimal places for both BTC and ETH to USD
    return ((uint256(price)*1e10) * amount) / 1e18; // 1e10 is the number of decimal places in the price feed and 1e18 is the number of decimal places in the token
}



// List of External View Functions

    function getCollateralTokens() external view returns(address[] memory){
        return collateralTokens;
    }

    function getSC() external view returns(address){
        return address(i_sc);
    }

    function getCollateralPriceFeed(address token) external view returns(address){
        return priceFeed[token];
    }

    function getHealthFactor(address user) external view returns(uint256){
        return healthFactor(user);
    }




}