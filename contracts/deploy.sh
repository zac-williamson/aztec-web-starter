# Compile the contracts
aztec-nargo compile

# Node URL and prover settings (can be overridden via environment variables)
: "${NODE_URL:=http://localhost:8080}"
: "${PXE_PROVER:=native}"

# Create an account
PXE_PROVER=$PXE_PROVER aztec-wallet create-account \
    --register-only \
    --node-url $NODE_URL \
    --alias deployer

# Register the SponsoredFPC contract
SPONSORED_FPC_ADDRESS=$(aztec get-canonical-sponsored-fpc-address | grep "Canonical SponsoredFPC Address:" | cut -d' ' -f4)
echo $SPONSORED_FPC_ADDRESS
PXE_PROVER=$PXE_PROVER aztec-wallet register-contract \
    --node-url $NODE_URL \
    --from deployer \
    --alias sponsoredfpc \
    $SPONSORED_FPC_ADDRESS SponsoredFPC \
    --salt 0

# Deploy the account contract
PXE_PROVER=$PXE_PROVER aztec-wallet deploy-account \
    --node-url $NODE_URL \
    --from deployer \
    --payment method=fpc-sponsored,fpc=contracts:sponsoredfpc \
    --register-class

# Deploy the Counter contract
PXE_PROVER=$PXE_PROVER aztec-wallet deploy \
    --from accounts:deployer \
    --payment method=fpc-sponsored,fpc=contracts:sponsoredfpc \
    --alias counter \
    --init initialize \
    ./target/counter-Counter.json \
    --args 0

# Generate the artifacts and save to the app directory
aztec codegen target --outdir ../app/artifacts
