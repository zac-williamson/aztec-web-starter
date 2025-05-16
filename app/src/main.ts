import { AztecAddress, Fr, Wallet, type AccountWallet } from '@aztec/aztec.js';
import { EmbeddedWallet } from './embedded-wallet.ts'
import { EasyPrivateVotingContract } from '../artifacts/EasyPrivateVoting.ts';
import deploymentInfo from '../deployed-contract.json';

// Local variables
let wallet: EmbeddedWallet;
const nodeUrl = import.meta.env.VITE_AZTEC_NODE_URL;
const votingContractDeployer = deploymentInfo.deployerAddress;
const votingContractSalt = deploymentInfo.deploymentSalt;
const votingContractAddress = deploymentInfo.contractAddress;

// DOM Elements
const createAccountButton = document.querySelector<HTMLButtonElement>('#create-account')!;
const voteForm = document.querySelector<HTMLFormElement>('.vote-form')!;
const voteButton = document.querySelector<HTMLButtonElement>('#vote-button')!;
const voteInput = document.querySelector<HTMLInputElement>('#vote-input')!;
const accountDisplay = document.querySelector<HTMLDivElement>('#account-display')!;
const statusMessage = document.querySelector<HTMLDivElement>('#status-message')!;
const voteResults = document.querySelector<HTMLDivElement>('#vote-results')!;


// On page load
document.addEventListener('DOMContentLoaded', async () => {
  try {
    // Initialize the PXE and the wallet
    displayStatusMessage('Connecting to node and initializing wallet...');
    wallet = new EmbeddedWallet(nodeUrl);
    await wallet.initialize();

    // Register Counter contract with PXE
    displayStatusMessage('Registering Private Counter...');
    await wallet.registerContract(
      EasyPrivateVotingContract.artifact,
      AztecAddress.fromString(votingContractDeployer),
      Fr.fromString(votingContractSalt),
      [AztecAddress.fromString(votingContractDeployer)]
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
voteButton.addEventListener('click', async (e) => {
  e.preventDefault();

  const candidate = parseInt(voteInput.value);
  if (isNaN(candidate) || candidate < 1 || candidate > 5) {
    displayError('Invalid candidate number');
    return;
  }

  const button = e.target as HTMLButtonElement;
  button.disabled = true;
  button.textContent = 'Voting...';

  try {
    // Prepare contract interaction
    const account = await wallet.getAccount();
    const counter = await EasyPrivateVotingContract.at(AztecAddress.fromString(votingContractAddress), account!);
    const interaction = counter.methods.cast_vote(candidate);

    // Send transaction
    await wallet.sendTransaction(interaction);

    // Update counter value
    updateCounterValue(account!);
  } catch (error) {
    displayError(error instanceof Error ? error.message : 'An unknown error occurred');
  } finally {
    button.disabled = false;
    button.textContent = 'Vote';
  }
});

// Update the counter value
async function updateCounterValue(account: Wallet) {
  let results: { [key: number]: number } = {};

  for (let i = 0; i < 5; i++) {
    // Prepare contract interaction
    const counter = await EasyPrivateVotingContract.at(AztecAddress.fromString(votingContractAddress), account);
    const interaction = counter.methods.get_vote(i);

    // Simulate the transaction
    const value = await wallet.simulateTransaction(interaction);
    results[i] = value;
  }

  // Display the counter value
  displayCounter(results);
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
    voteForm.style.display = 'none';
    return;
  }

  const address = account.getAddress().toString();
  const content = `Account: ${address.slice(0, 6)}...${address.slice(-4)}`;
  accountDisplay.textContent = content;
  createAccountButton.style.display = 'none';
  voteForm.style.display = 'block';
}

function displayCounter(results: { [key: number]: number }) {
  voteResults.textContent = Object.entries(results).map(
    ([key, value]) => `Candidate ${key}: ${value} votes`
  ).join('\n');
}
