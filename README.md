# Prerequisites
- You have a running local Chainlink Node. You can run node locally from this [repository](https://github.com/Aurum-Platform/chainlink-node) to do that.

# Repo Structure
 * **[`contract`](./contracts/):** contains API consumer, Oracle and Aurum Client contract.
 * **[`job-spec`](./job-spec/):** contains node job TOML schema/data pipeline.
 * **[`server`](./src/):** contains server-side script code for a Chainlink bridge, which initiates the request to an external API.

# External Adapter Data Structures

## Request Data

Requests to External Adapters conform to the following structure ([docs](https://docs.chain.link/docs/developers/#requesting-data)).

You can check that your external adapter is responsive by sending it a manual `curl` request that simulates what it would receive from a Chainlink Node.

A sample curl request to the External Adapter for the Alchemy API will look like:
`curl -X POST -H "content-type:application/json" "http://localhost:8080/" --data '{ "id": 10, "data": { "tokenAddress":"0xe785E82358879F061BC3dcAC6f0444462D4b5330"} }'`


When interacting with a Chainlink Node, the External Adapter will receive a post request that looks something like this:

```bash
{
  data: { tokenAddress: '0xe785E82358879F061BC3dcAC6f0444462D4b5330' },
  id: '0x93fd920063d2462d8dce013a7fc75656',
  meta: {
    oracleRequest: {
     // .... some data ....
    }
  }
}

```

## Response Data

Our external adapter returns data in the following structure ([docs](https://docs.chain.link/docs/developers/#returning-data)).

```bash 
returned response:   {
  "jobRunId":'0x93fd920063d2462d8dce013a7fc75656',
  "statusCode":200,
  "data": {
    "result": {
      "openSea": {
        "floorPrice":0.8,
        "priceCurrency":"ETH",
        "collectionUrl":"https://opensea.io/collection/world-of-women-nft",
        "retrievedAt":"2023-09-23T11:28:27.198Z"
      },
      "looksRare": {
        "floorPrice":0.94,
        "priceCurrency":"ETH",
        "collectionUrl":"https://looksrare.org/collections/0xe785e82358879f061bc3dcac6f0444462d4b5330",
        "retrievedAt":"2023-09-23T11:28:27.213Z"
      }
    }
  },
  "error":""
}
```

The response data will be paresed according to [Floor-Price-Job](./job-spec/floor-price-job.toml) TOML data pipeline (through running job in chainlink local node) along the path of `opensea,floorprice` to get a `uint256` responce in oracle

# Architecture Diagram

![alt Architecture Drawing Showing The Interaction within the System](./architecture.png "Architecture Diagram")
