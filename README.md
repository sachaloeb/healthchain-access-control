# HealthChain Access Control

A privacy-preserving blockchain dApp for managing **patient consent** and **secure access to off-chain medical data** in a healthcare setting.

The platform is built as part of the *Decentralized Digital Identity and Data Sharing* project and focuses on:

- Patient-centric control over medical data
- Time-limited, revocable consent
- Immutable audit logs of **all** data access attempts
- Off-chain storage for sensitive medical records (only hashes + references on-chain)

> ⚠️ **Important:** This repository is for academic use only.  
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

Planned/in progress:

- `IdentityRegistry` for hashed identities
- `ConsentManager` for consent creation, revocation, and validation
- Token / incentive mechanism for controlled data sharing
- Optional front-end (Viem.js) for interaction with the local Hardhat node

---

## Tech Stack

- **Blockchain / Contracts**
  - Solidity `^0.8.20` (compiled with `0.8.28`)
  - Hardhat v3
- **Testing**
  - Hardhat Solidity tests using `forge-std/Test.sol`
  - Node’s `node:test` for JavaScript/TypeScript tests (from template)
- **Tooling**
  - `@nomicfoundation/hardhat-toolbox-viem`
  - TypeScript
  - Ignition for deployments (`ignition/modules`)

---

## Repository Structure

```text
contracts/
  Counter.sol           # Hardhat template contract
  Counter.t.sol         # Example Solidity test from template
  DataSharing.sol       # Core project contract: off-chain data sharing logic
  DataSharing.t.sol     # Solidity unit tests for DataSharing

ignition/
  modules/
    Counter.ts          # Example Ignition deployment module (template)

scripts/
  send-op-tx.ts         # Example script from Hardhat template

test/
  Counter.ts            # Node/TypeScript test for Counter

hardhat.config.ts       # Hardhat configuration (ESM)
package.json
tsconfig.json
