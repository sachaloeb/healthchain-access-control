from web3 import Web3
import json
import os

# Connecting to the local Hardhat node
provider_url = "http://127.0.0.1:8545"
w3 = Web3(Web3.HTTPProvider(provider_url))

if not w3.is_connected():
    raise Exception("Cant reach hardhat node. Is it running?")

# using first account from the list as deployer / admin
account_list = w3.eth.accounts
admin_account = account_list[0]

#
# Deploy ConsentManager
#
with open("./artifacts/contracts/ConsentManager.sol/ConsentManager.json", "r") as cm_file:
    consent_data = json.load(cm_file)
consent_abi = consent_data["abi"]
consent_code = consent_data["bytecode"]

ConsentManagerContract = w3.eth.contract(abi=consent_abi, bytecode=consent_code)
cm_txn = ConsentManagerContract.constructor().transact({"from": admin_account})
cm_receipt = w3.eth.wait_for_transaction_receipt(cm_txn)
cm_address = cm_receipt.contractAddress

print("ConsentManager deployed at:", cm_address)

#
# Deploy DataSharing (needs ConsentManager address in constructor)
#
with open("./artifacts/contracts/DataSharing.sol/DataSharing.json") as ds_file:
    ds_data = json.load(ds_file)
ds_abi = ds_data["abi"]
ds_code = ds_data["bytecode"]

DataSharingContract = w3.eth.contract(abi=ds_abi, bytecode=ds_code)
ds_txn = DataSharingContract.constructor(cm_address).transact({"from": admin_account})
ds_receipt = w3.eth.wait_for_transaction_receipt(ds_txn)
ds_address = ds_receipt.contractAddress

print("DataSharing deployed at:", ds_address)

#
# Deploy RewardToken
#
with open("./artifacts/contracts/RewardToken.sol/RewardToken.json") as rt_file:
    rt_data = json.load(rt_file)
rt_abi = rt_data["abi"]
rt_code = rt_data["bytecode"]

RewardTokenContract = w3.eth.contract(abi=rt_abi, bytecode=rt_code)
rt_txn = RewardTokenContract.constructor().transact({"from": admin_account})
rt_receipt = w3.eth.wait_for_transaction_receipt(rt_txn)
rt_address = rt_receipt.contractAddress

print("RewardToken deployed at:", rt_address)

#
# Wire contracts together:
#   RewardToken.setConsentManager(ConsentManager)
#   ConsentManager.setRewardToken(RewardToken)
#
reward_token = w3.eth.contract(address=rt_address, abi=rt_abi)
consent_manager = w3.eth.contract(address=cm_address, abi=consent_abi)

tx1 = reward_token.functions.setConsentManager(cm_address).transact(
    {"from": admin_account}
)
w3.eth.wait_for_transaction_receipt(tx1)

tx2 = consent_manager.functions.setRewardToken(rt_address).transact(
    {"from": admin_account}
)
w3.eth.wait_for_transaction_receipt(tx2)

print("Wiring complete: RewardToken <-> ConsentManager")

#
# Save deployed addresses to a local file (used later by tests / scripts)
#
deployment_data = {
    "ConsentManager": cm_address,
    "DataSharing": ds_address,
    "RewardToken": rt_address,
}

output_dir = "deployments/chain31337"
os.makedirs(output_dir, exist_ok=True)

save_path = os.path.join(output_dir, "deployed_addresses.json")
with open(save_path, "w") as out_file:
    json.dump(deployment_data, out_file, indent=4)

print("\nDeployment addresses written to", save_path)
