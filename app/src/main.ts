import { initPXE, createAccount as createAndDeployAccount } from './aztec.ts'
import { createLogger, PXE, Wallet } from '@aztec/aztec.js';
import { getCounter, incrementCounter, registerContract } from "./counter-contract.ts";

const nodeUrl = 'http://localhost:8080';
const logger = createLogger('counter');
const deployedContractAddress = "0x0d39c4f024ca34e1ac5ee5cc949c3a3d4d0992e6b092ed5c868af3ad19c0f11e";

function displayError(message: string) {
  const errorMessage = document.querySelector<HTMLDivElement>('#error-message')!;
  errorMessage.textContent = message;
  errorMessage.classList.add('error');
}

function displayCounterValue(value: string) {
  const counterValue = document.querySelector<HTMLDivElement>('#counter-value')!;
  counterValue.textContent = value;
}

let ecdsaWallet: Wallet;
let pxe: PXE;

document.querySelector<HTMLButtonElement>('#create-account')!.addEventListener('click', async (e) => {
  e.preventDefault();
  e.stopPropagation();
  (e.target as HTMLButtonElement).disabled = true;
  (e.target as HTMLButtonElement).textContent = 'Creating account...';

  try {
    logger.info('Creating account');
    pxe = await initPXE(nodeUrl, logger);
    ecdsaWallet = await createAndDeployAccount(pxe, logger);

    document.querySelector<HTMLButtonElement>('#increment-counter')!.disabled = false;
  } catch (error) {
    displayError(error instanceof Error ? error.message : 'An unknown error occurred');
  } finally {
    (e.target as HTMLButtonElement).disabled = false;
    (e.target as HTMLButtonElement).textContent = 'Create Account';
  }
});


document.querySelector<HTMLButtonElement>('#increment-counter')!.addEventListener('click', async (e) => {
  e.preventDefault();
  e.stopPropagation();
  (e.target as HTMLButtonElement).disabled = true;
  (e.target as HTMLButtonElement).textContent = 'Incrementing counter...';
  try {
    logger.info('Registering contract');
    await registerContract(pxe);

    const res = await incrementCounter(deployedContractAddress, ecdsaWallet, pxe);
    console.log(res);

    const currentValue = await getCounter(deployedContractAddress, ecdsaWallet);
    displayCounterValue(currentValue.toString());
  } catch (error) {
    displayError(error instanceof Error ? error.message : 'An unknown error occurred');
  } finally {
    (e.target as HTMLButtonElement).disabled = false;
    (e.target as HTMLButtonElement).textContent = 'Increment Counter';
  }
});