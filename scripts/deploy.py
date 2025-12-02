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
    #    If your constructor takes args, add them to ctor_args here.
    consent_addr = deploy_contract(w3, "ConsentManager")

    # 4) Wire RewardToken <-> ConsentManager (and optionally IdentityRegistry)
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

    # OPTIONAL: setConsentManager could also be called from here too, but constructor already did it.
    data_sharing = get_instance(w3, "DataSharing", data_sharing_addr)

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



# from web3 import Web3
# import json
# import os
#
# # Connecting to the local Hardhat node
# provider_url = "http://127.0.0.1:8545"
# w3 = Web3(Web3.HTTPProvider(provider_url))
#
# if not w3.is_connected():
#     raise Exception("Cant reach hardhat node. Is it running?")
#
# # using first account from the list as deployer / admin
# account_list = w3.eth.accounts
# admin_account = account_list[0]
#
# #
# # Deploy ConsentManager
# #
# with open("./artifacts/contracts/ConsentManager.sol/ConsentManager.json", "r") as cm_file:
#     consent_data = json.load(cm_file)
# consent_abi = consent_data["abi"]
# consent_code = consent_data["bytecode"]
#
# ConsentManagerContract = w3.eth.contract(abi=consent_abi, bytecode=consent_code)
# cm_txn = ConsentManagerContract.constructor().transact({"from": admin_account})
# cm_receipt = w3.eth.wait_for_transaction_receipt(cm_txn)
# cm_address = cm_receipt.contractAddress
#
# print("ConsentManager deployed at:", cm_address)
#
# #
# # Deploy DataSharing (needs ConsentManager address in constructor)
# #
# with open("./artifacts/contracts/DataSharing.sol/DataSharing.json") as ds_file:
#     ds_data = json.load(ds_file)
# ds_abi = ds_data["abi"]
# ds_code = ds_data["bytecode"]
#
# DataSharingContract = w3.eth.contract(abi=ds_abi, bytecode=ds_code)
# ds_txn = DataSharingContract.constructor(cm_address).transact({"from": admin_account})
# ds_receipt = w3.eth.wait_for_transaction_receipt(ds_txn)
# ds_address = ds_receipt.contractAddress
#
# print("DataSharing deployed at:", ds_address)
#
# #
# # Deploy RewardToken
# #
# with open("./artifacts/contracts/RewardToken.sol/RewardToken.json") as rt_file:
#     rt_data = json.load(rt_file)
# rt_abi = rt_data["abi"]
# rt_code = rt_data["bytecode"]
#
# RewardTokenContract = w3.eth.contract(abi=rt_abi, bytecode=rt_code)
# rt_txn = RewardTokenContract.constructor().transact({"from": admin_account})
# rt_receipt = w3.eth.wait_for_transaction_receipt(rt_txn)
# rt_address = rt_receipt.contractAddress
#
# print("RewardToken deployed at:", rt_address)
#
# with open("./artifacts/contracts/IdentityRegistry.sol/IdentityRegistry.json") as ir_file:
#     ir_data = json.load(ir_file)
# ir_abi = ir_data["abi"]
# ir_code = ir_data["bytecode"]
#
# IdentityRegistryContract = w3.eth.contract(abi=ir_abi, bytecode=ir_code)
# ir_txn = IdentityRegistryContract.constructor().transact({"from": admin_account})
# ir_receipt = w3.eth.wait_for_transaction_receipt(ir_txn)
# ir_address = ir_receipt.contractAddress
#
# print("IdentityRegistry deployed at:", ir_address)
#
# #
# # Wire contracts together:
# #   RewardToken.setConsentManager(ConsentManager)
# #   ConsentManager.setRewardToken(RewardToken)
# #
# reward_token = w3.eth.contract(address=rt_address, abi=rt_abi)
# consent_manager = w3.eth.contract(address=cm_address, abi=consent_abi)
# identity_registry = w3.eth.contract(address=ir_address, abi=ir_abi)
# data_sharing = w3.eth.contract(address=ds_address, abi=ds_abi)
#
# tx1 = reward_token.functions.setConsentManager(cm_address).transact(
#     {"from": admin_account}
# )
# w3.eth.wait_for_transaction_receipt(tx1)
#
# tx2 = consent_manager.functions.setRewardToken(rt_address).transact(
#     {"from": admin_account}
# )
# w3.eth.wait_for_transaction_receipt(tx2)
#
# print("Wiring complete: RewardToken <-> ConsentManager")
#
# #
# # Save deployed addresses to a local file (used later by tests / scripts)
# #
# deployment_data = {
#     "ConsentManager": cm_address,
#     "DataSharing": ds_address,
#     "RewardToken": rt_address,
#     "IdentityRegistry": ir_address,
# }
#
# output_dir = "deployments/chain31337"
# os.makedirs(output_dir, exist_ok=True)
#
# save_path = os.path.join(output_dir, "deployed_addresses.json")
# with open(save_path, "w") as out_file:
#     json.dump(deployment_data, out_file, indent=4)
#
# print("\nDeployment addresses written to", save_path)
