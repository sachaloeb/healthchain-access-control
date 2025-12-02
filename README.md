# HealthChain Access Control

A privacy-preserving blockchain dApp for managing **patient consent** and **secure access to off-chain medical data** in a healthcare setting.

The platform is built as part of the *Decentralized Digital Identity and Data Sharing* project and focuses on:

- Patient-centric control over medical data
- Time-limited, revocable consent
- Immutable audit logs of **all** data access attempts
- Off-chain storage for sensitive medical records (only hashes + references on-chain)

> **Important:** This repository is for academic use only.  
> Never use real patient data when testing or demonstrating the system.

---

## Features

- **DataSharing smart contract**
  - Stores only **hashes** and **pointers (URIs)** to off-chain medical data
  - Enforces access via an external `ConsentManager` (`hasValidConsent(...)`)
  - Emits `AccessGranted` and `AccessDenied` events for every access attempt
- **Solidity unit tests** (Hardhat + forge-std style)
  - Tests for data registration, access control, and audit logging
- **Hardhat v3 project**
  - Local development environment
  - ESM-based Hardhat config
  - Viem & Ignition toolchain pre-configured by Hardhat template

---

## Tech Stack

- **Blockchain / Contracts**
  - Solidity `^0.8.20` (compiled with `0.8.28`)
  - Hardhat v3
- **Testing**
  - Hardhat Solidity tests using `forge-std/Test.sol`
  - Python scripts (`scripts/*.py`) for local interaction with contracts.
- **Tooling**
  - `@nomicfoundation/hardhat-toolbox-viem`
  - TypeScript
  - Ignition for deployments (`ignition/modules`)

---

## Repository Structure

```text
contracts/
  ConsentManager.sol
  DataSharing.sol
  IdentityRegistry.sol
  RewardToken.sol

scripts/
  deploy.py          # deploy to local Hardhat, save addresses
  testConsent.py     # example interaction with ConsentManager
  send-op-tx.ts      # OP chain demo (optional)

test/
  ConsentManager.t.sol
  DataSharing.t.sol
  IdentityRegistry.t.sol
  RewardToken.t.sol
  SystemWorkflow.t.sol

hardhat.config.ts
package.json
tsconfig.json
```

## Running the project

```bash
npm install
npx hardhat compile
npx hardhat node

python ./scripts/deploy.py
python ./scripts/testConsent.py
```
