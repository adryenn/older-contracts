pragma solidity ^0.5.16;

import "./AggregatorV3Interface.sol";
import "./PriceOracle.sol";
import "./ErrorReporter.sol";

contract ChainlinkPriceOracle is PriceOracle, OracleErrorReporter {

    /**
     * @notice Administrator for this contract
     */
    address public admin;

    /**
     * @notice Mapping of (cToken Address => AggregatorV3Interface Price Feed Address)
     */
    mapping(address => address) public priceFeeds;

    /**
     * @notice Emitted when a price feed is added for a cToken
     */
    event PriceFeedAdded(address indexed cTokenAddress, address indexed priceFeedAddress);

    /**
     * @notice Emitted when an existing price feed is replaced for a cToken
     */
    event PriceFeedReplaced(address indexed cTokenAddress, address indexed oldPriceFeed, address indexed newPriceFeed);

    /**
     * @notice Create a ChailninkPriceOracle contract
     */
    constructor() public {
        admin = msg.sender;
    }

    /**
     * @notice Get the underlying price of a cToken asset
     * @param cToken The cToken to get the underlying price of
     * @return The underlying asset price
     */
    function getUnderlyingPrice(CToken cToken) public view returns (uint) {
        // Check that a price feed exists for the cToken
        address priceFeedAddress = priceFeeds[address(cToken)];
        require(priceFeedAddress != address(0), "Price feed doesn't exist");

        // Get the price
        (,int price,,,) = AggregatorV3Interface(priceFeedAddress).latestRoundData();

        // Check that the price is not negative
        require(price >= 0, "Price cannot be negative");

        return uint(price);
    }

    /*** Admin Functions ***/

    /**
     * @notice Add a price feed for a cToken
     * @param cTokenAddress The address of the cToken
     * @param newPriceFeedAddress The address of the price feed
     * @return Whether or not the price feed was added
     */
    function _addPriceFeed(address cTokenAddress, address newPriceFeedAddress) external returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.ADD_PRICE_FEED_OWNER_CHECK);
        }

        // Check that a feed does not exist already
        if (priceFeeds[cTokenAddress] != address(0)) {
            return fail(Error.INVALID_INPUT, FailureInfo.ADD_PRICE_FEED_EXISTS);
        }

        // Set new feed
        priceFeeds[cTokenAddress] = newPriceFeedAddress;
        // Emit that a price feed has been added
        emit PriceFeedAdded(cTokenAddress, newPriceFeedAddress);

        return uint(Error.NO_ERROR);
    }

    /**
     * @notice Remove a price feed for a cToken by replacing the price feed
     * address with a zero address
     * @param cTokenAddress The address of the cToken
     * @return Whether or not the price feed was removed
     */
    function _removePriceFeed(address cTokenAddress) external returns (uint) {
        return _replacePriceFeed(cTokenAddress, address(0));
    }

    /**
     * @notice Replace a price feed for a cToken
     * @param cTokenAddress The address of the cToken
     * @param newPriceFeedAddress The address of the new price feed
     * @return Whether or not the price feed was replaced
     */
    function _replacePriceFeed(address cTokenAddress, address newPriceFeedAddress) public returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            return fail(Error.UNAUTHORIZED, FailureInfo.REPLACE_PRICE_FEED_OWNER_CHECK);
        }

        // Check that a feed exists to replace
        if (priceFeeds[cTokenAddress] == address(0)) {
            return fail(Error.INVALID_INPUT, FailureInfo.REPLACE_PRICE_FEED_NO_EXISTS);
        }

        // Get the old feed
        address oldPriceFeedAddress = priceFeeds[cTokenAddress];

        // Check that the new price feed is different from the old
        if (oldPriceFeedAddress == newPriceFeedAddress) {
            return fail(Error.INVALID_INPUT, FailureInfo.REPLACE_PRICE_FEED_WITH_DUPLICATE);
        }

        // Set the new feed
        priceFeeds[cTokenAddress] = newPriceFeedAddress;
        // Emit that a feed has been replaced
        emit PriceFeedReplaced(cTokenAddress, oldPriceFeedAddress, newPriceFeedAddress);

        return uint(Error.NO_ERROR);
    }

}
