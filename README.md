# aztec-web-starter

This is an example web app that demonstrates how to interact with an Aztec contract using the Aztec JS SDK.

- Uses a variation of the [Counter Contract](https://docs.aztec.network/developers/tutorials/codealong/contract_tutorials/counter_contract)
- Includes a browser-based wallet. This is only for demonstration purposes and not for production use.
- Works on top of the Sandbox, but can be adapted to work with a testnet.

### Setup

1. Start Aztec Sandbox by following the [Quick Start Guide](https://docs.aztec.network/developers/getting_started).

Please note that this project is using `v0.85.0-alpha-testnet` version of Aztec and you should be running the Sandbox with the same version.

```sh
aztec-up alpha-testnet
aztec start --sandbox
```


2. Deploy the contract in `/contracts`:

```sh
(cd contracts && ./deploy.sh)
```

The deploy script compiles the contract and deploys it using the default account that comes with the sandbox.

Once deployed, the script will output the contract address and the account that deployed it:

```
...
New account:

Address:         0x18c10565dc4a02a3dd6ae8e345f914b211cbaf3f588faffe82cfb437b173c294

...

# Contract deployed at 0x1d9b00c29e7103bad93c31649bc2f5f7d1b9c1b10fb36be104a2c26def20dd2f
# Contract partial address 0x0ea51c9a708bc8ebe2251a294e8f1611fae229d117eb32da8031c86514427f1b
# Contract init hash 0x1cb09a70d3ef572458dfb67db30a95339320d880d05f62642a18a9f68a678584
# Deployment tx hash: 0x0843bad0bba4c43fbef7a7cf620aee667e5a791d0046e3e2e97b800a57fece1a
# Deployment salt: 0x232562de65c426ded49dc945f5bf92a98d44b3403bc06de5998fa0aca511ebc5
# Deployment fee: 1427845120
...
```

3. Copy the values from above and paste them in the `.env` file:

```
VITE_COUNTER_CONTRACT_DEPLOYER= // Address displayed under "New account" at the top
VITE_COUNTER_CONTRACT_SALT= // Value of "Deployment salt: "
VITE_COUNTER_CONTRACT_ADDRESS= // Value after "Contract deployed at"
```

4. Install dependencies:

```sh
(cd app && yarn install)
```

5. Run the app:

```sh
(cd app && yarn dev)
```

<br />

You can now interact with the deployed contract using the web app:

- Create a new account (which will also save it to local storage)
- Increment the counter
- Refresh the page and see the account and counter value loaded with the previous value


### Disable client proofs

The Sanbox can accept transactions without the client-side proof. You can disable proof generation when working against the Sandbox as it will save time during development.

To disable proving on the deploy script, run:

```sh
PXE_PROVER=none ./deploy.sh
```

To disable proving in the web app, you can add the following line in `app/src/local-wallet.ts` (uncomment it):

```ts
config.proverEnabled = false;
```
