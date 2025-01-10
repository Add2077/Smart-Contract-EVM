// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RandomNFT is
    ERC721URIStorage,
    ERC721Enumerable,
    ERC721Burnable,
    Ownable,
    AccessControl,
    Pausable,
    VRFConsumerBaseV2,
    ReentrancyGuard
{
    enum MintType {
        Normal,
        Exchange
    }

    struct RequestStatus {
        bool fulfilled;
        address owner;
        uint256[] exchangeTokenId;
        uint256[] newTokenId;
        MintType mintType;
    }
    bytes32 public constant WORKER_ROLE = keccak256("WORKER_ROLE");

    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    using Strings for uint256;

    uint64 public s_subscriptionId;
    bytes32 public s_keyHash;
    uint32 public callbackGasLimit;
    uint16 public requestConfirmations;
    VRFCoordinatorV2Interface public COORDINATOR;
    uint256 requestId;

    string private baseExtension = ".json";
    uint256 public maxSupply;
    string baseURI;
    uint256 private _numAvailableTokens;

    mapping(uint256 => uint256) private _availableTokens;
    mapping(uint256 => RequestStatus) requestMints;

    event MintNFTs(
        address indexed to,
        uint256 indexed tokenId,
        uint256 requestId
    );
    event RequestMints(address indexed to, uint256 requestId);

    constructor(
        uint256 _maxSupply,
        string memory _baseURIs,
        address _vrfCoordinator,
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    )
        Ownable(msg.sender)
        VRFConsumerBaseV2(_vrfCoordinator)
        ERC721("MoreMeme", "MOREMEME")
    {
        maxSupply = _maxSupply;
        baseURI = _baseURIs;
        _numAvailableTokens = _maxSupply;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        s_keyHash = _keyHash;
        s_subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
    }

    /**
     * @dev Revert receive and fallback functions.
     */

    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }

    // VRF set

    function setVrfCoordinator(address _vrfCoordinator) external onlyOwner {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    function setkeyHash(bytes32 _keyHash) external onlyOwner {
        s_keyHash = _keyHash;
    }

    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        s_subscriptionId = _subscriptionId;
    }

    function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

    function setRequestConfirmations(uint16 _requestConfirmations)
        external
        onlyOwner
    {
        requestConfirmations = _requestConfirmations;
    }

    // VRF setBaseURIs
    function setBaseURIs(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function totalMint() public view returns (uint256) {
        return tokenIds.current();
    }

    function mintNFT() external  nonReentrant{
        require(
            tokenIds.current() <= maxSupply,
            " Minting exceeds the maximum supply"
        );
        uint32 numWords = 1;
        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        RequestStatus storage request = requestMints[requestId];
        request.owner = msg.sender;
        request.mintType = MintType.Normal;

        emit RequestMints(msg.sender, requestId);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        uint256 updatedNumAvailableTokens = _numAvailableTokens;
        RequestStatus storage request = requestMints[_requestId];
        address Owner = request.owner;
        for (uint256 i = 0; i < _randomWords.length; i++) {
            uint256 tokenId = getRandomAvailableTokenId(
                updatedNumAvailableTokens,
                _randomWords[i]
            );
            request.mintType == MintType.Normal;
            emit MintNFTs(Owner, tokenId, _requestId);

            _safeMint(Owner, tokenId);
            tokenIds.increment();
            request.newTokenId.push(tokenId);
            --updatedNumAvailableTokens;
            request.fulfilled = true;
            _numAvailableTokens = updatedNumAvailableTokens;
        }
    }

    function getRandomAvailableTokenId(
        uint256 updatedNumAvailableTokens,
        uint256 _randomWords
    ) internal returns (uint256) {
        uint256 randomNum = _randomWords;
        uint256 randomIndex = (randomNum % updatedNumAvailableTokens) + 1;
        return getAvailableTokenAtIndex(randomIndex, updatedNumAvailableTokens);
    }

    function getAvailableTokenAtIndex(
        uint256 indexToUse,
        uint256 updatedNumAvailableTokens
    ) internal returns (uint256) {
        uint256 valAtIndex = _availableTokens[indexToUse];
        uint256 result;
        if (valAtIndex == 0) {
            // This means the index itself is still an available token
            result = indexToUse;
        } else {
            // This means the index itself is not an available token, but the val at that index is.
            result = valAtIndex;
        }

        uint256 lastIndex = updatedNumAvailableTokens - 1;
        if (indexToUse != lastIndex) {
            // Replace the value at indexToUse, now that it's been used.
            // Replace it with the data from the last index in the array, since we are going to decrease the array size afterwards.
            uint256 lastValInArray = _availableTokens[lastIndex];
            if (lastValInArray == 0) {
                // This means the index itself is still an available token
                _availableTokens[indexToUse] = lastIndex;
            } else {
                // This means the index itself is not an available token, but the val at that index is.
                _availableTokens[indexToUse] = lastValInArray;
                // Gas refund courtsey of @dievardump
                delete _availableTokens[lastIndex];
            }
        }
        return result;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        string memory baseURIs = _baseURI();
        return
            bytes(baseURIs).length > 0
                ? string(
                    abi.encodePacked(
                        baseURIs,
                        _tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function checkRequesStatus(uint256 _requestId)
        public
        view
        returns (
            bool fulfilled,
            address owner,
            uint256[] memory exchangeTokenId,
            uint256[] memory newTokenId,
            MintType mintType
        )
    {
        RequestStatus memory request = requestMints[_requestId];
        fulfilled = request.fulfilled;
        owner = request.owner;
        exchangeTokenId = request.exchangeTokenId;
        newTokenId = request.newTokenId;
        mintType = request.mintType;
    }

    /**
     * @dev Override _increaseBalance.
     */

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    /**
     * @dev Override _update.
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev require function for ERC721, ERC721Enumerable.
     */
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
