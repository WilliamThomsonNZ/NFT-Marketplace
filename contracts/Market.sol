// contracts/Market.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    address payable owner;
    uint256 listingPrice = 0.025 ether;

    constructor() {
        owner = payable(msg.sender);
    }

    //Essentialy the object for our items
    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }
    //Creates a map for id to marketItem object
    mapping(uint256 => MarketItem) private idToMarketItem;
    //The indexed parameters for logged events will allow you to search for these events using the indexed parameters as filters.
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable nonReentrant {
        //First we check the validation ensure the right things are being sent etc
        require(price > 0, "price must be at least 1 wei");
        //Ensure enought ether is sent to list the item.
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );
        //We then do what ever logic is needed, in this case increment the token ID and store the struct in the idToMakretItem struct

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            //setting the address to nothing as no one actually is the owner
            payable(address(0)),
            price,
            false
        );
        //This is the logic that allows us to transfer the item to the contract.
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false
        );
    }

    //Use the nonreentrant modifier when we are intreacting with other contracts as this is when the reeentrentant attack is most likely to happen.
    function createMarketSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        //Get the token price and ID that the sender wants to buy.
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].itemId;
        //Check to see that the value msg.sender is equal to the price of the item.
        require(
            msg.value == price,
            "Please send the correct amount to complete the price"
        );
        //Transfer the funds from msg.sender to the seller of the item
        idToMarketItem[itemId].seller.transfer(msg.value);
        //send the item to the buyer
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        //Update the item struct to show the new owner and set the listing to sold.
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;

        //Pay the owner of the contact the listing price.
        payable(owner).transfer(listingPrice);
    }

    //Delist an item that has not sold yet
    function delistMarketItem(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        uint256 tokenId = idToMarketItem[itemId].itemId;
        address nftSeller = idToMarketItem[itemId].seller;
        require(msg.sender == nftSeller, "You are not the lister of this NFT");
        //This will transfer the item back to the sender.
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        delete idToMarketItem[itemId];
        _itemIds.decrement();
    }

    //Return all unsold market Items
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        //get the current tells us length because we increment each time an item is created
        uint256 numberItems = _itemIds.current();

        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex;
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        for (uint256 i = 0; i < numberItems; i++) {
            //Check here if the contract address owns the item, if it does then we know its listed and not sold.
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                //Create a struct for the current item so we can store it
                MarketItem storage currentItem = idToMarketItem[currentId];
                //This is essentially instead of array.push()
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItems = _itemIds.current();
        uint256 myItemCount = 0;
        //We need this so we can track how to place the items in the array
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItems; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                myItemCount += 1;
            }
        }
        MarketItem[] memory myItems = new MarketItem[](myItemCount);
        for (uint256 i = 0; i < myItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                MarketItem storage currentMyItem = idToMarketItem[i + 1];

                myItems[currentIndex] = currentMyItem;
                currentIndex += 1;
            }
        }
        return myItems;
    }

    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItems = _itemIds.current();
        uint256 myCreatedItemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItems; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                myCreatedItemCount += 1;
            }
        }
        MarketItem[] memory myCreatedItems = new MarketItem[](
            myCreatedItemCount
        );

        for (uint256 i = 0; i < myCreatedItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                MarketItem storage item = idToMarketItem[i + 1];

                myCreatedItems[currentIndex] = item;
                currentIndex += 1;
            }
        }

        return myCreatedItems;
    }
}
