import {
  AccountManager,
  AccountWalletWithSecretKey,
  Fr,
  Logger,
  type PXE,
} from '@aztec/aztec.js';
import { randomBytes } from '@aztec/foundation/crypto';
import { getEcdsaRAccount } from '@aztec/accounts/ecdsa/lazy';
import { getSponsoredPFCPaymentMethod } from './aztec.ts';

const LocalStorageKey = 'aztec-account';

export async function createAccount(pxe: PXE, logger: Logger) {
  const salt = Fr.random();
  const secretKey = Fr.random();
  const signingKey = randomBytes(32);
  const ecdsaAccount = await getEcdsaRAccount(pxe, secretKey, signingKey, salt);

  const deployMethod = await ecdsaAccount.getDeployMethod();
  const deployOpts = {
    contractAddressSalt: Fr.fromString(ecdsaAccount.salt.toString()),
    fee: {
      paymentMethod: await ecdsaAccount.getSelfPaymentMethod(await getSponsoredPFCPaymentMethod(pxe)),
    },
    universalDeploy: true,
    skipClassRegistration: true,
    skipPublicDeployment: true,
  };
  const provenInteraction = await deployMethod.prove(deployOpts);
  const receipt = await provenInteraction.send().wait({ timeout: 120 });

  logger.info('Account deployed', receipt);

  const ecdsaWallet = await ecdsaAccount.getWallet();
  console.log(Array.from(signingKey));
  localStorage.setItem(LocalStorageKey, JSON.stringify({
    address: ecdsaWallet.getAddress().toString(),
    signingKey: signingKey.toString('hex'),
    secretKey: secretKey.toString(),
    salt: salt.toString(),
  }));

  await ecdsaAccount.register();

  console.log('ecdsaAccount', ecdsaAccount.getAddress().toString());
  const registeredAccounts = await pxe.getRegisteredAccounts();
  console.log('registeredAccounts', registeredAccounts.map(s => s.address.toString()));

  return ecdsaWallet;
}

export async function getAccount(pxe: PXE) {
  const account = localStorage.getItem(LocalStorageKey);
  if (!account) {
    return null;
  }
  const parsed = JSON.parse(account);

  const ecdsaAccount = await getEcdsaRAccount(pxe,
    Fr.fromString(parsed.secretKey),
    Buffer.from(parsed.signingKey, 'hex'),
    Fr.fromString(parsed.salt)
  );

  await ecdsaAccount.register();
  const ecdsaWallet = await ecdsaAccount.getWallet();

  // const { isContractPubliclyDeployed } = await pxe.getContractMetadata(ecdsaWallet.getAddress());
  // if (!isContractPubliclyDeployed) {
  //   return null;
  // }

  return ecdsaWallet;
}