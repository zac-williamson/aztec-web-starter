import fs from 'fs';
import path from 'path';
import { AztecAddress, createAztecNodeClient, DeployMethod, Fr, getContractInstanceFromDeployParams, PublicKeys, PXE, SponsoredFeePaymentMethod, Wallet } from "@aztec/aztec.js";
import { createPXEService, getPXEServiceConfig } from "@aztec/pxe/server";
import { getEcdsaRAccount } from '@aztec/accounts/ecdsa/lazy';
import { createStore } from "@aztec/kv-store/lmdb";
import { randomBytes } from '@aztec/foundation/crypto';
import { getDefaultInitializer } from '@aztec/stdlib/abi';
import { EasyPrivateVotingContract } from '../artifacts/EasyPrivateVoting';
import { SponsoredFPCContractArtifact } from '@aztec/noir-contracts.js/SponsoredFPC';
import { SPONSORED_FPC_SALT } from '@aztec/constants';

const NODE_URL = process.env.NODE_URL || 'http://localhost:8080';
const PROVER_ENABLED = process.env.PROVER_ENABLED === 'false' ? false : true;

async function setupPXE() {
	const aztecNode = createAztecNodeClient(NODE_URL);

	const store = await createStore('pxe', {
		dataDirectory: path.join(import.meta.dirname, '.store'),
		dataStoreMapSizeKB: 1e6,
	});

	const config = getPXEServiceConfig();
	config.dataDirectory = 'pxe';
	config.proverEnabled = PROVER_ENABLED;
	const l1Contracts = await aztecNode.getL1ContractAddresses();
	const configWithContracts = {
		...config,
		l1Contracts,
	};

	const pxe = await createPXEService(aztecNode, configWithContracts, true, store);
	return pxe;
};

async function getSponsoredPFCContract() {
	const instance = await getContractInstanceFromDeployParams(SponsoredFPCContractArtifact, {
		salt: new Fr(SPONSORED_FPC_SALT),
	});

	return instance
}

async function createAccount(pxe: PXE) {
	const salt = Fr.random();
	const secretKey = Fr.random();
	const signingKey = randomBytes(32);
	const ecdsaAccount = await getEcdsaRAccount(pxe, secretKey, signingKey, salt);

	const deployMethod = await ecdsaAccount.getDeployMethod();
	const sponsoredPFCContract = await getSponsoredPFCContract();
	const deployOpts = {
		contractAddressSalt: Fr.fromString(ecdsaAccount.salt.toString()),
		fee: {
			paymentMethod: await ecdsaAccount.getSelfPaymentMethod(
				new SponsoredFeePaymentMethod(sponsoredPFCContract.address)
			),
		},
		universalDeploy: true,
		skipClassRegistration: true,
		skipPublicDeployment: true,
	};
	const provenInteraction = await deployMethod.prove(deployOpts);
	await provenInteraction.send().wait({ timeout: 120 });

	await ecdsaAccount.register();
	const wallet = await ecdsaAccount.getWallet();

	return {
		wallet,
		credentials: {
			salt: salt.toString(),
			secretKey: secretKey.toString(),
			signingKey: Buffer.from(signingKey).toString('hex'),
			address: wallet.getAddress().toString()
		}
	};
}

async function deployContract(pxe: PXE, deployer: Wallet) {
	const salt = Fr.random();
	const contract = await getContractInstanceFromDeployParams(EasyPrivateVotingContract.artifact, {
		publicKeys: PublicKeys.default(),
		constructorArtifact: getDefaultInitializer(EasyPrivateVotingContract.artifact),
		constructorArgs: [deployer.getAddress().toField()],
		deployer: deployer.getAddress(),
		salt,
	});

	const deployMethod = new DeployMethod(
		contract.publicKeys,
		deployer,
		EasyPrivateVotingContract.artifact,
		(address: AztecAddress, wallet: Wallet) => EasyPrivateVotingContract.at(address, wallet),
		[deployer.getAddress().toField()],
		getDefaultInitializer(EasyPrivateVotingContract.artifact)?.name,
	);

	const sponsoredPFCContract = await getSponsoredPFCContract();

	const provenInteraction = await deployMethod.prove({
		contractAddressSalt: salt,
		fee: {
			paymentMethod: new SponsoredFeePaymentMethod(sponsoredPFCContract.address)
		},
	});
	await provenInteraction.send().wait({ timeout: 120 });
	await pxe.registerContract({ instance: contract, artifact: EasyPrivateVotingContract.artifact });

	return {
		contractAddress: contract.address.toString(),
		deployerAddress: deployer.getAddress().toString(),
		deploymentSalt: salt.toString(),
	}
}


async function main() {
	const pxe = await setupPXE();
	await pxe.registerContract({ instance: await getSponsoredPFCContract(), artifact: SponsoredFPCContractArtifact });

	// Create a new account
	const { wallet, credentials } = await createAccount(pxe);

	// Deploy the contract
	const deploymentInfo = await deployContract(pxe, wallet);
	console.log(deploymentInfo);

	// Combine all information
	const fullInfo = {
		walletInfo: credentials,
		deploymentInfo
	};

	fs.writeFileSync(
		path.join(import.meta.dirname, '../deployed-contract.json'),
		JSON.stringify(fullInfo, null, 2)
	);

	// Simple output with just wallet info and deployment info
	console.log('\n--- WALLET INFO ---');
	console.log(credentials);
	
	console.log('\n--- DEPLOYMENT INFO ---');
	console.log(deploymentInfo);

	console.log('\n\n\nContract deployed successfully. All info saved to deployed-contract.json\n\n\nIMPORTANT: Do not lose this file as you will not be able to recover the contract address if you lose it.\n\n\n');
}

main();