import React, { useState, useEffect } from "react";
import { ethers } from "ethers";
import axios from "axios";
import Web3Modal from "web3modal";

// import {
//     nftaddress, nftmarketaddress
//   } from '../config'

import NFT from "../artifacts/contracts/NFT.sol/NFT.json";
import Market from "../artifacts/contracts/Market.sol/NFTMarket.json";
import { loadConfig } from "@ethereum-waffle/compiler/dist/esm/config";

const nftaddres = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const nftmarketaddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

const Page = () => {
  const [allListedNfts, setAllListedNfts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  useEffect(() => {
    getNfts();
  }, []);

  const getNfts = async () => {
    //Since we are just reading from the blockcahin we only need to create a provider and don't need the user to sign anything.
    //sets the contract up so that we can intract with it.
    const provider = new ethers.providers.JsonRpcProvider();
    const tokenContract = new ethers.Contract(nftaddres, NFT.abi, provider);
    const marketContract = new ethers.Contract(
      nftmarketaddress,
      Market.abi,
      provider
    );
    const data = await marketContract.fetchMarketItems();
    console.log(data);
    //Format the response and fetch the tokens meta data
    let items = [];
    items = await Promise.all(
      data.map(async (i) => {
        const tokenURI = await tokenContract.tokenURI(i.tokenId);
        const meta = await axios.get(tokenURI);
        console.log(meta);
        const price = ethers.utils.formatUnits(i.price.toString(), "ether");
        const item = {
          price,
          tokenId: i.tokenId.toNumber(),
          seller: i.seller,
          owner: i.owner,
          image: meta.data.image,
          name: meta.data.name,
          description: meta.data.description,
        };
        return item;
      })
    );

    console.log(items);
    setAllListedNfts(items);
    setIsLoading(false);
  };

  const buyNft = async (nft) => {
    //We need the signer because a transaction needs to happen
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();
    const contract = new ethers.Contract(nftmarketaddress, Market.abi, signer);
    console.log(nft.price);
    const price = ethers.utils.parseUnits("0.5", "ether");
    console.log(price);
    const transaction = await contract.createMarketSale(
      nftaddres,
      nft.tokenId,
      {
        value: price,
      }
    );

    await transaction.wait();
    getNfts();
  };

  return (
    <>
      {isLoading ? (
        <h1>Loading...</h1>
      ) : !allListedNfts.length ? (
        <h1>No items in marketplace</h1>
      ) : (
        <div>
          {allListedNfts.map((nft) => (
            <div>
              <h1>{nft.name}</h1>
              <h2>{nft.tokenId}</h2>
              <img
                src={nft.image}
                style={{ width: "200px", height: "200px" }}
              />
              <button className="" onClick={() => buyNft(nft)}>
                Buy
              </button>
            </div>
          ))}
        </div>
      )}
    </>
  );
};

export default Page;
