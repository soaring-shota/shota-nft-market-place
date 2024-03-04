# Aliveland NFT Market

## Prerequisite

- [NodeJS](https://nodejs.org/en/download)

## Setup

Clone the project

```bash
  git clone https://github.com/aliveland/aliveland-nft-contract.git
```

Go to the project directory

```bash
  cd aliveland-nft-contract
```

Install dependencies

```bash
  npm install
```

Compile smart contract

```bash
  npm run compile
```

Set environment variables

- POLYGON_API_URL : Node URL for connecting to Polygon mainnet
- ALCHEMY_API_KEY : Alchemy API key. (Reference: https://docs.alchemy.com/reference/api-overview)
- MUMBAI_API_URL : Node URL for connecting to Polygon Mumbai testnet
- METAMASK_PRIVATE_KEY : Private key of a local Metamask wallet to be used for testing
- POLYGONSCAN_API_KEY : Polgyonscan API key. (Reference: https://docs.polygonscan.com/getting-started/viewing-api-usage-statistics)

## Run Locally

```bash
  npm run unit-test
```

## Deployment

Deploy smart contract on Mumbai testnet

```bash
  npm run deploy-mumbai
```

Deploy smart contract on Mumbai testnet

```bash
  npm run deploy-polygon
```