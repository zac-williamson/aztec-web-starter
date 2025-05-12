# Compile the contracts
aztec-nargo compile

# Create an account to deploy the contracts
export NODE_URL=http://localhost:8080
SPONSORED_FPC_ADDRESS=$(aztec get-canonical-sponsored-fpc-address | grep "Canonical SponsoredFPC Address:" | cut -d' ' -f4)
echo $SPONSORED_FPC_ADDRESS

aztec-wallet create-account \
    --register-only \
    --node-url $NODE_URL \
    --alias deployer

aztec-wallet register-contract \
    --node-url $NODE_URL \
    --from deployer \
    --alias sponsoredfpc \
    $SPONSORED_FPC_ADDRESS SponsoredFPC \
    --salt 0

aztec-wallet deploy-account \
    --node-url $NODE_URL \
    --from deployer \
    --payment method=fpc-sponsored,fpc=contracts:sponsoredfpc \
    --register-class

aztec-wallet deploy \
    --from accounts:deployer \
    --payment method=fpc-sponsored,fpc=contracts:sponsoredfpc \
    --alias counter \
    --init initialize \
    ./target/counter-Counter.json \
    --args 0


# Contract deployed at 0x1d9b00c29e7103bad93c31649bc2f5f7d1b9c1b10fb36be104a2c26def20dd2f
# Contract partial address 0x0ea51c9a708bc8ebe2251a294e8f1611fae229d117eb32da8031c86514427f1b
# Contract init hash 0x1cb09a70d3ef572458dfb67db30a95339320d880d05f62642a18a9f68a678584
# Deployment tx hash: 0x0843bad0bba4c43fbef7a7cf620aee667e5a791d0046e3e2e97b800a57fece1a
# Deployment salt: 0x232562de65c426ded49dc945f5bf92a98d44b3403bc06de5998fa0aca511ebc5
# Deployment fee: 1427845120
