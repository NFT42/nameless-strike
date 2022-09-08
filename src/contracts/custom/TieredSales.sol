// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';

import '../nameless/NamelessToken.sol';

contract TieredSales is AccessControl, Initializable  {

  address payable public benefactor;
  string public name;

  event TokenPurchased(uint index, address buyer);

  struct Stats {
    uint32 numSold;
    uint32 maxPubsale;
    uint32 firstTokenId;
    uint160 price;
  }

  Stats[] public tier;
  bool public saleActive;
  NamelessToken public tokenContract;


  function initialize(string memory _name, NamelessToken _tokenContract, address initialAdmin) public initializer {
    name = _name;
    benefactor = payable(initialAdmin);
    _setupRole(DEFAULT_ADMIN_ROLE, initialAdmin);

    saleActive = false;
    tokenContract = _tokenContract;
  }

  constructor(string memory _name, NamelessToken _tokenContract) {
    initialize(_name, _tokenContract, msg.sender);
  }

  function pickTokenId(uint _tier) internal returns (uint) {
    tier[_tier].numSold++;
    return tier[_tier].firstTokenId++;
  }

  function addTier(Stats[] calldata _newTiers) external onlyRole(DEFAULT_ADMIN_ROLE){
    uint idx = 0;
    while(idx < _newTiers.length) {
      tier.push(_newTiers[idx]);
      idx++;
    }
  }

  function buy(uint _tier, uint quantity) external payable {
    require(saleActive, 'sale not started');
    require(SafeMath.mul(tier[_tier].price, quantity) == msg.value, 'wrong price');
    require(SafeMath.add(tier[_tier].numSold, quantity) <= tier[_tier].maxPubsale, 'Sold out');

    for (uint i = 0; i < quantity; i++) {
      uint tokenId = pickTokenId(_tier);
      tokenContract.mint(msg.sender, tokenId);
      emit TokenPurchased(tokenId, msg.sender);
    }
  }

  function setSaleActive(bool active) external onlyRole(DEFAULT_ADMIN_ROLE) {
    saleActive = active;
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