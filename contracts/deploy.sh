# Compile the contracts
aztec-nargo compile

# Create an account to deploy the contracts
export NODE_URL=http://localhost:8080

# Create an account
aztec-wallet create-account \
    --register-only \
    --node-url $NODE_URL \
    --alias deployer

# Register the SponsoredFPC contract
SPONSORED_FPC_ADDRESS=$(aztec get-canonical-sponsored-fpc-address | grep "Canonical SponsoredFPC Address:" | cut -d' ' -f4)
echo $SPONSORED_FPC_ADDRESS
aztec-wallet register-contract \
    --node-url $NODE_URL \
    --from deployer \
    --alias sponsoredfpc \
    $SPONSORED_FPC_ADDRESS SponsoredFPC \
    --salt 0

# Deploy the account contract
aztec-wallet deploy-account \
    --node-url $NODE_URL \
    --from deployer \
    --payment method=fpc-sponsored,fpc=contracts:sponsoredfpc \
    --register-class

# Deploy the Counter contract
aztec-wallet deploy \
    --from accounts:deployer \
    --payment method=fpc-sponsored,fpc=contracts:sponsoredfpc \
    --alias counter \
    --init initialize \
    ./target/counter-Counter.json \
    --args 0

# Generate the artifacts and save to the app directory
aztec codegen target --outdir ../app/artifacts
