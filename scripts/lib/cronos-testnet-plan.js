import { getAddress, id, parseUnits, ZeroAddress } from 'ethers';

export const CRONOS_TESTNET_CHAIN_ID = 338n;
export const CRONOS_MAINNET_CHAIN_ID = 25n;
export const TESTNET_ROUTE_LABEL =
  'XTC:CRONOS-TESTNET:338:XITCOIN-TESTNET-V2-1';
export const TESTNET_ROUTE_ID = id(TESTNET_ROUTE_LABEL);

const DEAD_ADDRESS = '0x000000000000000000000000000000000000dEaD';

function address(value, label) {
  let result;
  try {
    result = getAddress(String(value ?? ''));
  } catch {
    throw new Error(`${label} must be a valid EVM address`);
  }
  if (result === ZeroAddress || result.toLowerCase() === DEAD_ADDRESS.toLowerCase()) {
    throw new Error(`${label} must not be a zero or dead address`);
  }
  return result;
}

function amount(value, label) {
  const text = String(value ?? '').trim();
  if (!/^(?:0|[1-9][0-9]*)(?:\.[0-9]{1,18})?$/.test(text)) {
    throw new Error(`${label} must be a non-negative decimal with at most 18 decimals`);
  }
  const result = parseUnits(text, 18);
  if (result <= 0n) throw new Error(`${label} must be greater than zero`);
  return result;
}

export function validateCronosTestnetPlan(input) {
  if (!input || typeof input !== 'object') {
    throw new Error('Cronos testnet deployment plan is required');
  }
  const chainId = BigInt(input.chainId);
  if (chainId !== CRONOS_TESTNET_CHAIN_ID) {
    throw new Error('Cronos testnet chain ID must be 338');
  }
  const signers = Array.isArray(input.signers)
    ? input.signers.map((value, index) => address(value, `signer ${index + 1}`))
    : [];
  if (signers.length !== 3 || new Set(signers.map((value) => value.toLowerCase())).size !== 3) {
    throw new Error('exactly three distinct testnet signers are required');
  }
  const guardian = address(input.guardian, 'guardian');
  if (signers.some((value) => value.toLowerCase() === guardian.toLowerCase())) {
    throw new Error('guardian must be separate from the testnet signers');
  }
  const tokenRecipient = address(input.tokenRecipient, 'test token recipient');
  const tokenSupply = amount(input.tokenSupply, 'test token supply');
  const maxReleaseAmount = amount(input.maxReleaseAmount, 'maximum release amount');
  const dailyReleaseLimit = amount(input.dailyReleaseLimit, 'daily release limit');
  if (maxReleaseAmount > dailyReleaseLimit) {
    throw new Error('maximum release amount must not exceed the daily limit');
  }
  return Object.freeze({
    chainId,
    routeLabel: TESTNET_ROUTE_LABEL,
    routeId: TESTNET_ROUTE_ID,
    signers: Object.freeze(signers),
    guardian,
    tokenRecipient,
    tokenSupply,
    maxReleaseAmount,
    dailyReleaseLimit
  });
}
