// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RandomNFT is
    ERC721URIStorage,
    ERC721Enumerable,
    ERC721Burnable,
    Ownable,
    AccessControl,
    Pausable,
    ReentrancyGuard
{
    bytes32 public constant WORKER_ROLE = keccak256("WORKER_ROLE");
    using Strings for uint256;
    uint256 private _numAvailableTokens;

    string private baseExtension = ".json";
    uint256 public maxSupply;
    string baseURI;

    mapping(uint256 => uint256) private _availableTokens;
    event Minted(address owner, uint256 tokenId);

    constructor(uint256 _maxSupply, string memory _baseURIs)
        Ownable(msg.sender)
        ERC721("Pokmon Trading Card Game", "Pokemon TCG")
    {
        maxSupply = _maxSupply;
        baseURI = _baseURIs;
        _numAvailableTokens = _maxSupply;
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

    function setBaseURIs(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function randomMintNFT() external nonReentrant {
        require(totalSupply() <= maxSupply, "Exceeds max supply");
        uint256 updatedNumAvailableTokens = _numAvailableTokens;
        uint256 randomSeed = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.number, msg.sender)
            )
        );
        uint256 tokenId = getRandomAvailableTokenId(
            updatedNumAvailableTokens,
            randomSeed
        );
        _safeMint(msg.sender, tokenId);
        --updatedNumAvailableTokens;
        emit Minted(msg.sender, tokenId);

        _numAvailableTokens = updatedNumAvailableTokens;
    }

    function getRandomAvailableTokenId(
        uint256 updatedNumAvailableTokens,
        uint256 _randomWords
    ) internal returns (uint256) {
        uint256 randomNum = _randomWords;
        uint256 randomIndex = randomNum % updatedNumAvailableTokens;
        return
            getAvailableTokenAtIndex(randomIndex, updatedNumAvailableTokens) +
            1;
    }

    function getAvailableTokenAtIndex(
        uint256 indexToUse,
        uint256 updatedNumAvailableTokens
    ) internal returns (uint256) {
        uint256 valAtIndex = _availableTokens[indexToUse];
        uint256 result;
        if (valAtIndex == 0) {
            result = indexToUse;
        } else {
            result = valAtIndex;
        }

        uint256 lastIndex = updatedNumAvailableTokens - 1;
        if (indexToUse != lastIndex) {
            uint256 lastValInArray = _availableTokens[lastIndex];
            if (lastValInArray == 0) {
                _availableTokens[indexToUse] = lastIndex;
            } else {
                _availableTokens[indexToUse] = lastValInArray;
            }
        }
        return result;
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

    function multiGrantRole(bytes32 _role, address[] memory _workerAddress)
        external
        onlyOwner
    {
        uint256 _length = _workerAddress.length;
        for (uint256 i = 0; i < _length; i++) {
            grantRole(_role, _workerAddress[i]);
        }
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

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
