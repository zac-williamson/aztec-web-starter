rm -rf ./target
rm -rf ./codegenCache.json

# Compile the contracts
aztec-nargo compile

# Generate the artifacts and save to the app directory
aztec codegen target --outdir ./target

cp ./target/*.ts ./target/*.json ./../app/artifacts