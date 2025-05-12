import { AztecAddress, Fr, Wallet, type AccountWallet } from '@aztec/aztec.js';
import { LocalWallet } from './local-wallet.ts'
import { CounterContract } from '../artifacts/Counter.ts';

// Aztec Node URL
const nodeUrl = 'http://localhost:8080';

// Address of the deployed Counter contract
const deployedContract = {
  address: "0x10f78b7ca79d779669ac6446b5fea179b2be4b2747af05839f4909166f596414",
  deployer: '0x1a41081a4e0dea2a0595258faa8531ac5cbe4a736ccd44c5c0827ca8720eae29',
  salt: '0x24d65691d1c691b19826e32faa1021f4bed7163bf6be98e78af88246a16f4163'
}

// Local variables
let wallet: LocalWallet;

// DOM Elements
const createAccountButton = document.querySelector<HTMLButtonElement>('#create-account')!;
const incrementCounterButton = document.querySelector<HTMLButtonElement>('#increment-counter')!;
const accountDisplay = document.querySelector<HTMLDivElement>('#account-display')!;
const statusMessage = document.querySelector<HTMLDivElement>('#status-message')!;
const counterValue = document.querySelector<HTMLDivElement>('#counter-value')!;


// On page load
document.addEventListener('DOMContentLoaded', async () => {
  try {
    // Initialize the PXE and the wallet
    displayStatusMessage('Initializing local wallet...');
    wallet = new LocalWallet(nodeUrl);
    await wallet.initialize();

    // Register Counter contract with PXE
    displayStatusMessage('Registering Private Counter...');
    await wallet.registerContract(
      CounterContract.artifact,
      AztecAddress.fromString(deployedContract.deployer),
      Fr.fromString(deployedContract.salt),
      [0]
    );

    // Get existing account
    displayStatusMessage('Checking for existing account...');
    const account = await wallet.getAccount();
    await displayAccount(account);

    // Refresh counter if account exists
    if (account) {
      await updateCounterValue(account);
      displayStatusMessage('');
    } else {
      displayStatusMessage('Creating new account to setup your private counter...');
    }
  } catch (error) {
    displayError(error instanceof Error ? error.message : 'An unknown error occurred');
  }
});

// Create a new account
createAccountButton.addEventListener('click', async (e) => {
  e.preventDefault();
  const button = e.target as HTMLButtonElement;
  button.disabled = true;
  button.textContent = 'Creating account...';

  try {
    const account = await wallet.createAccount();
    displayAccount(account);

    // Refresh counter value (not really needed though, as the default value is 0)
    await updateCounterValue(account);
  } catch (error) {
    displayError(error instanceof Error ? error.message : 'An unknown error occurred');
  } finally {
    button.disabled = false;
    button.textContent = 'Create Account';
  }
});

// Increment the counter
incrementCounterButton.addEventListener('click', async (e) => {
  e.preventDefault();
  const button = e.target as HTMLButtonElement;
  button.disabled = true;
  button.textContent = 'Incrementing counter...';

  try {
    // Prepare contract interaction
    const account = await wallet.getAccount();
    const counter = await CounterContract.at(AztecAddress.fromString(deployedContract.address), account!);
    const interaction = counter.methods.increment();

    // Send transaction
    await wallet.sendTransaction(interaction);

    // Update counter value
    updateCounterValue(account!);
  } catch (error) {
    displayError(error instanceof Error ? error.message : 'An unknown error occurred');
  } finally {
    button.disabled = false;
    button.textContent = 'Increment Counter';
  }
});

// Update the counter value
async function updateCounterValue(account: Wallet) {
  // Prepare contract interaction
  const counter = await CounterContract.at(AztecAddress.fromString(deployedContract.address), account);
  const interaction = counter.methods.get_counter(account.getAddress());

  // Simulate the transaction
  const value = await wallet.simulateTransaction(interaction);
  
  // Display the counter value
  displayCounter(value);
}

// UI functions

function displayError(message: string) {
  statusMessage.textContent = message;
  statusMessage.classList.add('error');
  statusMessage.style.display = 'block';
}

function displayStatusMessage(message: string) {
  statusMessage.textContent = message;
  statusMessage.classList.remove('error');
  statusMessage.style.display = message ? 'block' : 'none';
}

function displayAccount(account: AccountWallet | null) {
  if (!account) {
    createAccountButton.style.display = 'block';
    incrementCounterButton.disabled = true;
    return;
  }

  const address = account.getAddress().toString();
  const content = `Account: ${address.slice(0, 6)}...${address.slice(-4)}`;
  accountDisplay.textContent = content;
  createAccountButton.style.display = 'none';
  incrementCounterButton.disabled = false;
}

function displayCounter(value: number) {
  counterValue.textContent = value.toString();
}
