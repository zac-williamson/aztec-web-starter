import {
  AztecAddress,
  createAztecNodeClient,
  Fr,
  getContractInstanceFromDeployParams,
  loadContractArtifact,
  Logger,
  SponsoredFeePaymentMethod,
  type PXE,
} from '@aztec/aztec.js';
import { randomBytes } from '@aztec/foundation/crypto';
import { getEcdsaRAccount } from '@aztec/accounts/ecdsa/lazy';
import { getPXEServiceConfig } from '@aztec/pxe/config';
import { createPXEService } from '@aztec/pxe/client/lazy';
// import { SponsoredFPCContract } from '@aztec/noir-contracts.js/SponsoredFPC';
import SponsoredFPC from '../artifacts/0.85.0-alpha-testnet.2/sponsored_fpc_contract-SponsoredFPC.json';
import { SPONSORED_FPC_SALT } from '@aztec/constants';

export async function initPXE(nodeURL: string, logger: Logger): Promise<PXE> {
  const aztecNode = await createAztecNodeClient(nodeURL);

  const config = getPXEServiceConfig();
  config.l1Contracts = await aztecNode.getL1ContractAddresses();
  // config.proverEnabled = false;
  const pxe = await createPXEService(aztecNode, config);

  const nodeInfo = await pxe.getNodeInfo();
  logger.info('PXE Connected to node', nodeInfo);

  return pxe;
}

export async function getSponsoredPFCPaymentMethod(
  pxe: PXE,
): Promise<SponsoredFeePaymentMethod> {
  const artifact = await loadContractArtifact(SponsoredFPC)
  const instance = await getContractInstanceFromDeployParams(artifact, {
    salt: new Fr(SPONSORED_FPC_SALT),
  });

  await pxe.registerContract({
    instance: instance,
    artifact: artifact,
  });
  return new SponsoredFeePaymentMethod(instance.address);

}

export async function createAccount(pxe: PXE, logger: Logger) {
  console.log('pxe', pxe);
  const salt = Fr.random();
  const secretKey = Fr.random();
  const signingKey = randomBytes(32);
  const ecdsaAccount = await getEcdsaRAccount(pxe, secretKey, signingKey, salt);
  const ecdsaWallet = await ecdsaAccount.getWallet();
  await ecdsaAccount.register();

  logger.info('ECDSA Account created', ecdsaWallet);

  // Deploy account
  const deployMethod = await ecdsaAccount.getDeployMethod();
  const deployOpts = {
    contractAddressSalt: salt,
    fee: {
      paymentMethod: await ecdsaAccount.getSelfPaymentMethod(await getSponsoredPFCPaymentMethod(pxe)),
    },
    universalDeploy: true,
    skipClassRegistration: true,
    skipPublicDeployment: true,
  };
  const provenInteraction = await deployMethod.prove(deployOpts);
  const txHash = await provenInteraction.getTxHash();
  console.log(txHash);
  const receipt = await provenInteraction.send().wait({ timeout: 120 });
  console.log(receipt);

  return ecdsaWallet;
}
