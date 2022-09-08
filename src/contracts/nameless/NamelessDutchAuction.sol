// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';

import './NamelessToken.sol';

contract NamelessDutchAuction is AccessControl, Initializable  {
  struct ListingInfo {
    uint64         decayStartTime;
    uint64         decayEndTime;
    uint           initialPrice;
    uint           finalPrice;
    NamelessToken  tokenContract;
    address        minter;
    uint[]         tokenIds;
  }

  ListingInfo[] public listings;
  mapping(uint => bool) public listingActive;
  mapping(uint => uint) public nextTokenIndex;

  address payable public benefactor;
  string public name;

  event ListingPurchased(uint256 indexed listingId, uint index, address buyer, uint256 price);

  function initialize(string memory _name, address initialAdmin) public initializer {
    name = _name;
    benefactor = payable(initialAdmin);
    _setupRole(DEFAULT_ADMIN_ROLE, initialAdmin);
  }

  constructor(string memory _name) {
    initialize(_name, msg.sender);
  }

  function calculateCurrentPrice(ListingInfo memory template) internal view returns (uint256) {
    // solhint-disable-next-line not-rely-on-time
    uint256 currentTime = block.timestamp;
    uint256 delta = template.initialPrice - template.finalPrice;

    if (currentTime >= template.decayEndTime) {
      return template.finalPrice;
    } else if (currentTime <= template.decayStartTime) {
      return template.initialPrice;
    }


    uint256 reduction =
      SafeMath.div(SafeMath.mul(delta, currentTime - template.decayStartTime ), template.decayEndTime - template.decayStartTime);
    return template.initialPrice - reduction;
  }

  function calculateCurrentPrice(uint256 listingId) public view returns (uint256) {
    return calculateCurrentPrice(listings[listingId]);
  }

  function bid(uint256 listingId) public payable {
    require(listingActive[listingId] != false, 'listing not active');
    require(listingId < listings.length, 'No such listing');
    ListingInfo storage listing = listings[listingId];

    require(nextTokenIndex[listingId] < listing.tokenIds.length, 'Sold Out');

    uint256 currentPrice = calculateCurrentPrice(listing);
    uint256 tokenId = listing.tokenIds[nextTokenIndex[listingId]];
    nextTokenIndex[listingId] = nextTokenIndex[listingId] + 1;

    require(msg.value >= currentPrice, 'Wrong price');
    if (listing.minter == address(0)) {
      listing.tokenContract.mint(msg.sender, tokenId);
    } else {
      listing.tokenContract.mint(listing.minter, msg.sender, tokenId);
    }

    emit ListingPurchased(listingId, tokenId, msg.sender, currentPrice);

    if (currentPrice < msg.value) {
      Address.sendValue(payable(msg.sender), msg.value - currentPrice);
    }
  }

  function addListings( ListingInfo[] calldata newListings) public onlyRole(DEFAULT_ADMIN_ROLE) {
    uint idx = 0;
    while(idx < newListings.length) {
      listings.push(newListings[idx]);
      idx++;
    }
  }

  function setListingActive( uint[] calldata listingIds, bool active ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    uint idx = 0;
    while(idx < listingIds.length) {
      listingActive[listingIds[idx]] = active;
      idx++;
    }
  }

  function withdraw() public {
    require(msg.sender == benefactor || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 'not authorized');
    uint amount = address(this).balance;
    require(amount > 0, 'no balance');

    Address.sendValue(benefactor, amount);
  }

  function setBenefactor(address payable newBenefactor, bool sendBalance) public onlyRole(DEFAULT_ADMIN_ROLE) {
    require(benefactor != newBenefactor, 'already set');
    uint amount = address(this).balance;
    address payable oldBenefactor = benefactor;
    benefactor = newBenefactor;

    if (sendBalance && amount > 0) {
      Address.sendValue(oldBenefactor, amount);
    }
  }
}
