import {
  AztecAddress,
  getContractInstanceFromDeployParams,
  PublicKeys,
  Wallet,
  Fr,
  PXE,
} from '@aztec/aztec.js';
import { CounterContract } from '../artifacts/Counter.ts'
import { getDefaultInitializer } from '@aztec/stdlib/abi';
import { getSponsoredPFCPaymentMethod } from './aztec.ts';

export class PrivateCounter {
  constructor(
    private readonly pxe: PXE,
    private readonly address: string,
    private readonly deployer: string,
    private readonly salt: string,
  ) {
  }

  public async initialize() {
    const counterContractInstance = await getContractInstanceFromDeployParams(CounterContract.artifact, {
      publicKeys: PublicKeys.default(),
      constructorArtifact: getDefaultInitializer(CounterContract.artifact),
      constructorArgs: [0],
      deployer: AztecAddress.fromString(this.deployer),
      salt: Fr.fromHexString(this.salt),
    });

    if (counterContractInstance.address.toString() !== this.address) {
      throw new Error("Provided address does not match the computed address");
    }

    await this.pxe.registerContract({
      instance: counterContractInstance,
      artifact: CounterContract.artifact
    })
  }

  public async incrementCounter(account: Wallet) {
    console.log('this.address', this.address);
    const counter = await CounterContract.at(AztecAddress.fromString(this.address), account);
    await counter.methods.increment().send({
      fee: {
        paymentMethod: await getSponsoredPFCPaymentMethod(this.pxe),
      }
    }).wait();
  }

  public async getCounter(account: Wallet) {
    const counter = await CounterContract.at(AztecAddress.fromString(this.address), account);
    const res = await counter.methods.get_counter(account.getAddress()).simulate();
    return res;
  }
}

