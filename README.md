# Carbon Credits Trading and Verification System

A Clarity smart contract for managing tokenized carbon credits on the Stacks blockchain.

## Overview

This smart contract enables the creation, verification, trading, and retirement of carbon credits. It provides a transparent and immutable way to track carbon offset projects, verify emissions reductions, and facilitate the trading of tokenized carbon credits.

## Features

- **Project Registration**: Register carbon offset projects with detailed metadata
- **Verification Process**: Authorized verifiers can confirm emissions reductions
- **Credit Minting**: Projects can mint carbon credits once verified
- **Trading Mechanism**: Transfer credits between accounts
- **Credit Retirement**: Permanently retire credits with beneficiary tracking
- **Transparent Records**: All actions are tracked on-chain with auditable history

## Core Functions

### Administrative
- `register-project`: Register a new carbon offset project
- `add-authorized-verifier`: Add a new verifier to the authorized list
- `remove-authorized-verifier`: Remove a verifier from the authorized list
- `transfer-contract-ownership`: Transfer ownership of the contract

### Operations
- `verify-project`: Submit verification data for a project
- `mint-credits`: Mint new carbon credits for a verified project
- `transfer-credits`: Transfer carbon credits between accounts
- `retire-credits`: Permanently retire carbon credits

### Read-Only
- `get-project`: Get details about a specific project
- `get-credit-balance`: Get the credit balance for a specific owner and project
- `get-retirement`: Get details about a specific credit retirement
- `get-verification-record`: Get verification details for a project
- `get-contract-owner`: Get the current contract owner
- `is-authorized-verifier`: Check if an address is an authorized verifier

## Security Features

- Input validation for all public functions
- Authorization checks for administrative operations
- Proper validation of principal addresses
- Verification status requirements for minting
- Balance checks before transfers and retirements
- Protection against double retirement of credits

## Error Codes

| Code | Description |
|------|-------------|
| `ERR-NOT-AUTHORIZED` | Not authorized to perform this action |
| `ERR-PROJECT-EXISTS` | Project with this ID already exists |
| `ERR-PROJECT-NOT-FOUND` | Project not found |
| `ERR-VERIFICATION-FAILED` | Verification requirement not met |
| `ERR-INSUFFICIENT-CREDITS` | Insufficient credit balance |
| `ERR-CREDIT-ALREADY-RETIRED` | Credit has already been retired |
| `ERR-INVALID-AMOUNT` | Invalid amount specified |
| `ERR-INVALID-VERIFICATION-DATA` | Invalid verification data |
| `ERR-INVALID-INPUT` | Invalid input parameters |
| `ERR-INVALID-HASH` | Invalid hash provided |
| `ERR-INVALID-RECIPIENT` | Invalid recipient address |
| `ERR-INVALID-BENEFICIARY` | Invalid beneficiary address |

## Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - Clarity development toolchain

### Testing
Run the test suite:
```bash
clarinet test
```
