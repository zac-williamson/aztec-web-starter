rm -rf ../app/artifacts
rm -rf ./target
rm -rf ./codegenCache.json

# Compile the contracts
aztec-nargo compile

# Generate the artifacts and save to the app directory
aztec codegen target --outdir ../app/artifacts
