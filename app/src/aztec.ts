import {
  createAztecNodeClient,
  Fr,
  getContractInstanceFromDeployParams,
  loadContractArtifact,
  Logger,
  SponsoredFeePaymentMethod,
  type PXE,
} from '@aztec/aztec.js';
import { getPXEServiceConfig } from '@aztec/pxe/config';
import { createPXEService } from '@aztec/pxe/client/lazy';
import SponsoredFPC from '../artifacts/0.85.0-alpha-testnet.2/sponsored_fpc_contract-SponsoredFPC.json';
import { SPONSORED_FPC_SALT } from '@aztec/constants';

export async function initPXE(nodeURL: string, logger: Logger): Promise<PXE> {
  const aztecNode = await createAztecNodeClient(nodeURL);

  const config = getPXEServiceConfig();
  config.l1Contracts = await aztecNode.getL1ContractAddresses();
  config.proverEnabled = false;
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
