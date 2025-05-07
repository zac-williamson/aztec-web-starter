import {
  AztecAddress,
  getContractInstanceFromDeployParams,
  PublicKeys,
  Wallet,
  Fr,
  PXE,
} from '@aztec/aztec.js';
import { CounterContract } from '../artifacts/Counter'
import { getDefaultInitializer } from '@aztec/stdlib/abi';
import { getSponsoredPFCPaymentMethod } from './aztec.ts';

export async function registerContract(pxe: PXE) {
  const counterContractInstance = await getContractInstanceFromDeployParams(CounterContract.artifact, {
    publicKeys: PublicKeys.default(),
    constructorArtifact: getDefaultInitializer(CounterContract.artifact),
    constructorArgs: [0, "0x24281c4a9c04ae202968700ff0326b4d16dc3510a236beff9b2cd22f69d4ed02"],
    deployer: AztecAddress.fromString("0x24281c4a9c04ae202968700ff0326b4d16dc3510a236beff9b2cd22f69d4ed02"),
    salt: Fr.fromHexString("0x185acf02c4358345b203f9b08cb7608115d5e3ebe821d941f67ba42be6a21ff5"),
  });

  if (counterContractInstance.address.toString() !== '0x0d39c4f024ca34e1ac5ee5cc949c3a3d4d0992e6b092ed5c868af3ad19c0f11e') {
    throw new Error("invalid address");
  }
  await pxe.registerContract({
    instance: counterContractInstance,
    artifact: CounterContract.artifact
  })
}

export async function incrementCounter(
  contractAddress: string,
  account: Wallet,
  pxe: PXE
) {
  const counter = await CounterContract.at(AztecAddress.fromString(contractAddress), account);
  await counter.methods.increment(account.getAddress(), account.getAddress()).send({
    fee: {
      paymentMethod: await getSponsoredPFCPaymentMethod(pxe),
    }
  }).wait();
}

export async function getCounter(contractAddress: string, account: Wallet) {
  const tokenAsMinter = await CounterContract.at(AztecAddress.fromString(contractAddress), account);
  const res = await tokenAsMinter.methods.get_counter(account.getAddress()).simulate();
  return res;
}