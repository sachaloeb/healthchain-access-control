import json
import os
from pathlib import Path
from web3 import Web3

HARDHAT_RPC_URL = "http://127.0.0.1:8545"
CHAIN_ID = 31337


ARTIFACTS = Path("artifacts/contracts")
DEPLOYMENTS_DIR = Path(f"deployments/chain{CHAIN_ID}")
DEPLOYED_ADDRESSES_FILE = DEPLOYMENTS_DIR / "deployed_addresses.json"

def load_artifact(contract_name: str, file_name: str | None = None) -> dict:
    """
    Load Hardhat artifact for a given contract.

    By default assumes file_name == contract_name (e.g., DataSharing.sol/DataSharing.json).
    Adjust if your file and contract names differ.
    """
    if file_name is None:
        file_name = contract_name

    artifact_path = ARTIFACTS / f"{file_name}.sol" / f"{contract_name}.json"
    with artifact_path.open() as f:
        return json.load(f)


def deploy_contract(w3: Web3, contract_name: str, ctor_args=(), file_name: str | None = None) -> str:
    artifact = load_artifact(contract_name, file_name=file_name)
    bytecode = artifact["bytecode"]
    abi = artifact["abi"]

    contract = w3.eth.contract(abi=abi, bytecode=bytecode)
    tx_hash = contract.constructor(*ctor_args).transact({"from": w3.eth.accounts[0]})
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    address = receipt.contractAddress
    print(f"{contract_name} deployed at {address} (gas used: {receipt.gasUsed})")
    return address


def get_instance(w3: Web3, contract_name: str, address: str, file_name: str | None = None):
    artifact = load_artifact(contract_name, file_name=file_name)
    abi = artifact["abi"]
    return w3.eth.contract(address=address, abi=abi)



def main():
    w3 = Web3(Web3.HTTPProvider(HARDHAT_RPC_URL))
    assert w3.is_connected(), "Could not connect to Hardhat node"
    deployer = w3.eth.accounts[0]
    print(f"Using deployer: {deployer}")

    # 1) Deploy IdentityRegistry
    identity_addr = deploy_contract(w3, "IdentityRegistry")

    # 2) Deploy RewardToken
    reward_addr = deploy_contract(w3, "RewardToken")

    # 3) Deploy ConsentManager
    consent_addr = deploy_contract(w3, "ConsentManager")

    # 4) Wire RewardToken <-> ConsentManager and IdentityRegistry
    reward = get_instance(w3, "RewardToken", reward_addr)
    consent = get_instance(w3, "ConsentManager", consent_addr)
    identity = get_instance(w3, "IdentityRegistry", identity_addr)

    # RewardToken.setConsentManager(consent)
    tx_hash = reward.functions.setConsentManager(consent_addr).transact({"from": deployer})
    w3.eth.wait_for_transaction_receipt(tx_hash)
    print("RewardToken.setConsentManager wired")

    # ConsentManager.setRewardToken(reward)
    tx_hash = consent.functions.setRewardToken(reward_addr).transact({"from": deployer})
    w3.eth.wait_for_transaction_receipt(tx_hash)
    print("ConsentManager.setRewardToken wired")

    # 5) Deploy DataSharing with ConsentManager address
    data_sharing_addr = deploy_contract(w3, "DataSharing", ctor_args=(consent_addr,))

    # data_sharing = get_instance(w3, "DataSharing", data_sharing_addr)

    # ---------- Save addresses ----------

    DEPLOYMENTS_DIR.mkdir(parents=True, exist_ok=True)
    addresses = {
        "IdentityRegistry": identity_addr,
        "RewardToken": reward_addr,
        "ConsentManager": consent_addr,
        "DataSharing": data_sharing_addr,
    }

    with DEPLOYED_ADDRESSES_FILE.open("w") as f:
        json.dump(addresses, f, indent=4)

    print(f"Saved deployed addresses to {DEPLOYED_ADDRESSES_FILE}")


if __name__ == "__main__":
    main()