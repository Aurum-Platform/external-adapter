// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * @title AurumCLient
 * @dev API consumer contract to get floor price from oracle
 */

contract AurumCLient is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;
    address public oracle;
    string public jobId;
    address public aurumAddress;

    struct FloorPrice {
        uint256 floorPrice;
        uint256 deadline;
    }

    mapping(address => FloorPrice) private tokenToFloorPrice;
    uint256 private constant ORACLE_PAYMENT = (1 * LINK_DIVISIBILITY) / 1000; // 0.001 ETH (link token)
    uint256 public constant DEADLINE = 1 days;

    event RequestFloorPrice(bytes32 indexed requestId, uint256 floorPrice);

    modifier ownerOrAurumAddress {
        require(msg.sender == owner || msg.sender == aurumAddress, "Not Allowed");
        _;
    }

    /**
     * Sepolia
     * @dev LINK address in Sepolia network: 0x779877A7B0D9E8603169DdbD7836e478b4624789
     * @dev Check https://docs.chain.link/docs/link-token-contracts/ for LINK address for the right network
     */
    constructor(address _oracle, string memory _jobId) ConfirmedOwner(msg.sender) {
        oracle = _oracle;
        jobId = _jobId;
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
    }

    /**
     * @dev Returns the floor price of a given token address. If the floor price is not available,
     * It requests the price from the oracle and returns the current floor price.
     * @param _tokenAddress The address of the token to get the floor price for.
     * @return The floor price of the token.
     */
    function getFloorPrice(address _tokenAddress) external returns(FloorPrice memory) {
        if(tokenToFloorPrice[_tokenAddress].deadline >  block.timestamp) {
            return tokenToFloorPrice[_tokenAddress];
        }

        requestPrice(_tokenAddress);
        return tokenToFloorPrice[_tokenAddress];
    }

    /**
     * @dev Sets the address of the Aurum contract.
     * @param _aurumAddress The address of the Aurum contract.
     * Requirements:
     * - The caller must be the owner of the contract.
     */
    function setAurumAddress(address _aurumAddress) external onlyOwner {
        aurumAddress = _aurumAddress;
    }
    /**
     * @dev Requests the price of a token from the Aurum oracle.
     * @param _tokenAddress The address of the token to request the price for.
     * Emits a Chainlink request to the oracle with the specified job ID and callback function.
     * The response from the oracle should be in the following format:
     * {
     *   "openSea": {
     *     "floorPrice": 0.5788,
     *     "priceCurrency": "ETH",
     *     "collectionUrl": "https://opensea.io/collection/world-of-women-nft",
     *     "retrievedAt": "2023-09-03T03:22:35.534Z"
     *   },
     *   "looksRare": {
     *     "floorPrice": 0.98,
     *     "priceCurrency": "ETH",
     *     "collectionUrl": "https://looksrare.org/collections/0xe785e82358879f061bc3dcac6f0444462d4b5330",
     *     "retrievedAt": "2023-09-03T03:22:35.559Z"
     *   }
     * }
     * The response is then multiplied by 1e18 to get the value in wei.
     */

    function requestPrice(address _tokenAddress) public ownerOrAurumAddress {
        Chainlink.Request memory req = buildChainlinkRequest(
            toBytes32(jobId),
            address(this),
            this.fulfill.selector
        );
        string memory tokenAddress = toString(_tokenAddress);
        req.add("tokenAddress", tokenAddress);
        
        // Multiply the result by 1e18 to get value in wei
        int256 toWeiAmount = 10 ** 18;
        req.addInt("times", toWeiAmount);

        sendOperatorRequestTo(oracle, req, ORACLE_PAYMENT);
    }

    /**
     * @dev Receive the response in the form of uint256 and store the floor price for the given token address.
     * @param _requestId The ID of the Chainlink request.
     * @param _tokenAddress The address of the token for which the floor price is being stored.
     * @param _floorPrice The floor price to be stored.
     */
    function fulfill(
        bytes32 _requestId,
        address _tokenAddress,
        uint256 _floorPrice
    ) public recordChainlinkFulfillment(_requestId) {
        emit RequestFloorPrice(_requestId, _floorPrice);
        FloorPrice memory priceStruct = FloorPrice({
            floorPrice: _floorPrice,
            deadline: block.timestamp + DEADLINE
        });
        tokenToFloorPrice[_tokenAddress] = priceStruct;
    }


    /*
    ========= UTILITY FUNCTIONS ==========
    */

    
    /**
     * @dev Converts an address to its string representation.
     * @param account The address to convert.
     * @return The string representation of the address.
     */
    function toString(address account) internal  pure returns(string memory) {
        return toString(abi.encodePacked(account));
    }

    /**
     * @dev Converts a bytes array to a hexadecimal string representation.
     * @param data The bytes array to convert.
     * @return The hexadecimal string representation of the input bytes array.
     */
    function toString(bytes memory data) internal pure returns(string memory) {
        bytes memory alphabet = "0123456789abcdef";
       
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    /**
     * @dev Returns the current ETH and LINK balances of the contract.
     * @return eth The current ETH balance of the contract.
     * @return link The current LINK balance of the contract.
     */
    function contractBalances()
        public
        view
        returns (uint256 eth, uint256 link)
    {
        eth = address(this).balance;

        LinkTokenInterface linkContract = LinkTokenInterface(
            chainlinkTokenAddress()
        );
        link = linkContract.balanceOf(address(this));
    }

    /**
     * @dev Returns the address of the Chainlink token.
     * @return The address of the Chainlink token.
     */
    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    /**
     * @dev Withdraws LINK tokens from the contract and transfers them to the contract owner.
     * Only the contract owner can call this function.
     * @notice This function requires that the contract has sufficient LINK balance.
     * @notice This function will revert if the LINK transfer fails.
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer Link"
        );
    }

    /**
     * @dev Withdraws the contract's balance to the owner's address.
     *      Only the owner can call this function.
     */
    function withdrawBalance() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev Cancels a Chainlink request using the specified parameters.
     * @param _requestId The ID of the Chainlink request to cancel.
     * @param _payment The amount of LINK tokens to refund for the cancelled request.
     * @param _callbackFunctionId The function ID of the callback function for the cancelled request.
     * @param _expiration The expiration time of the cancelled request.
     * Requirements:
     * - The caller must be the owner of the contract.
     */
    function cancelRequest(
        bytes32 _requestId,
        uint256 _payment,
        bytes4 _callbackFunctionId,
        uint256 _expiration
    ) public onlyOwner {
        cancelChainlinkRequest(
            _requestId,
            _payment,
            _callbackFunctionId,
            _expiration
        );
    }

    /**
     * @dev Converts a string to bytes32.
     * @param source The string to be converted.
     * @return result The bytes32 representation of the string.
     */
    function toBytes32(string memory source)
        private
        pure
        returns (bytes32 result)
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }
}
