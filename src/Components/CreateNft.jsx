import React, { useState } from "react";
import { ethers } from "ethers";
import { create as ipfsHttpClient } from "ipfs-http-client";
import Web3Modal from "web3modal";
import NFT from "../artifacts/contracts/NFT.sol/NFT.json";
import Market from "../artifacts/contracts/Market.sol/NFTMarket.json";

const client = ipfsHttpClient("https://ipfs.infura.io:5001/api/v0");

const nftaddres = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const nftmarketaddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

const CreateNft = () => {
  const [fileUrl, setFileUrl] = useState("");
  const [formInput, setFormInput] = useState({
    price: "",
    name: "",
    description: "",
  });

  async function handleFileUpload(e) {
    const file = e.target.files[0];
    //Upload file to IPFS and have access to the URL.
    try {
      const added = await client.add(file, {
        progress: (prog) => console.log(`received: ${prog}`),
      });
      const url = `https://ipfs.infura.io/ipfs/${added.path}`;
      setFileUrl(url);
    } catch (error) {
      console.log("There was an error uploading file: ", error);
    }
  }
  async function uploadToIpfs() {
    // const { name, description, price } = formInput;
    // if (!name || !description || !price || !fileUrl) return;
    console.log(fileUrl);
    const data = JSON.stringify({
      name: "test",
      description: "test",
      image: fileUrl,
    });

    try {
      const added = await client.add(data);
      const url = `https://ipfs.infura.io/ipfs/${added.path}`;
      console.log(url);
      createMarketItem(url);
    } catch (error) {
      console.log("Error uploading file: ", error);
    }
  }
  async function createMarketItem(url) {
    //This is how we open meta mask or other wallet.
    const web3Modal = new Web3Modal();
    const connection = await web3Modal.connect();
    const provider = new ethers.providers.Web3Provider(connection);
    const signer = provider.getSigner();

    //Create the Item by calling our NFT contract
    let contract = new ethers.Contract(nftaddres, NFT.abi, signer);
    let transaction = await contract.createToken(url);
    const tx = await transaction.wait();
    const tokenId = tx.events[0].args[2].toNumber();
    const price = ethers.utils.parseUnits("0.5", "ether");

    contract = new ethers.Contract(nftmarketaddress, Market.abi, signer);
    const listingPrice = await contract.getListingPrice();
    const lPrice = listingPrice.toString();
    transaction = await contract.createMarketItem(nftaddres, tokenId, price, {
      value: lPrice,
    });
    await transaction.wait();
    console.log(tokenId);
  }

  return (
    <div>
      <input type="file" name="Asset" onChange={handleFileUpload} />
      <button onClick={uploadToIpfs}>Create Digital Asset</button>
    </div>
  );
};

export default CreateNft;
