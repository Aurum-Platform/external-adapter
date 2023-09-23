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

    struct FloorPrice {
        uint256 floorPrice;
        uint256 deadline;
    }

    mapping(address => FloorPrice) private tokenToFloorPrice;
    uint256 private constant ORACLE_PAYMENT = (1 * LINK_DIVISIBILITY) / 1000; // 0.001 ETH (link token)
    uint256 public constant DEADLINE = 1 days;

    event RequestFloorPrice(bytes32 indexed requestId, uint256 floorPrice);

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

    function getFloorPrice(address _tokenAddress) external returns(FloorPrice memory) {
        if(tokenToFloorPrice[_tokenAddress].deadline >  block.timestamp) {
            return tokenToFloorPrice[_tokenAddress];
        }

        requestPrice(_tokenAddress);
        return tokenToFloorPrice[_tokenAddress];
    }

    function requestPrice(address _tokenAddress) public onlyOwner {
        Chainlink.Request memory req = buildChainlinkRequest(
            stringToBytes32(jobId),
            address(this),
            this.fulfill.selector
        );

        // Set the path to find the desired data in the API response, where the response format is:
        // {
        //   "openSea": {
        //     "floorPrice": 0.5788,
        //     "priceCurrency": "ETH",
        //     "collectionUrl": "https://opensea.io/collection/world-of-women-nft",
        //     "retrievedAt": "2023-09-03T03:22:35.534Z"
        //   },
        //   "looksRare": {
        //     "floorPrice": 0.98,
        //     "priceCurrency": "ETH",
        //     "collectionUrl": "https://looksrare.org/collections/0xe785e82358879f061bc3dcac6f0444462d4b5330",
        //     "retrievedAt": "2023-09-03T03:22:35.559Z"
        //   }
        // }
        string memory tokenAddress = toString(_tokenAddress);
        req.add("tokenAddress", tokenAddress);
        
        // Multiply the result by 1e18 to get value in wei
        int256 toWeiAmount = 10 ** 18;
        req.addInt("times", toWeiAmount);

        sendOperatorRequestTo(oracle, req, ORACLE_PAYMENT);
    }

    /**
     * Receive the response in the form of uint256
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

    
    function toString(address account) internal  pure returns(string memory) {
        return toString(abi.encodePacked(account));
    }

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

    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer Link"
        );
    }

    function withdrawBalance() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

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

    function stringToBytes32(string memory source)
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
