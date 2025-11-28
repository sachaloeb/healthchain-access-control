from web3 import Web3
import json

# Connecting to the local Hardhat node
provider_url = "http://127.0.0.1:8545"
w3 = Web3(Web3.HTTPProvider(provider_url))

if not w3.is_connected():
    raise Exception("Cant reach hardhat node. Is it running?")

# using first account from the list as deployer
account_list = w3.eth.accounts
admin_account = account_list[0]

# Setting up ConsentManager
with open("./artifacts/contracts/ConsentManager.sol/ConsentManager.json", "r") as cm_file:
    consent_data = json.load(cm_file)
consent_abi = consent_data["abi"]
consent_code = consent_data["bytecode"]

# Prepare contract deployment
ConsentManagerContract = w3.eth.contract(abi=consent_abi, bytecode=consent_code)
# Deploy
# Note: might add constructor args later if needed
deploy_txn = ConsentManagerContract.constructor().transact({"from": admin_account})

# Wait until its mined
cm_receipt = w3.eth.wait_for_transaction_receipt(deploy_txn)
cm_address = cm_receipt.contractAddress

print("ConsentManager contract deployed at -", cm_address)

# Setting up DataSharing 
with open("./artifacts/contracts/DataSharing.sol/DataSharing.json") as ds_file:
    ds_data = json.load(ds_file)

ds_abi = ds_data["abi"]
ds_code = ds_data["bytecode"]

# Deploy and pass COnsentManager address to the constructor
DataSharingContract = w3.eth.contract(abi=ds_abi, bytecode=ds_code)

ds_txn = DataSharingContract.constructor(cm_address).transact({"from": admin_account})
ds_receipt = w3.eth.wait_for_transaction_receipt(ds_txn)
ds_address = ds_receipt.contractAddress

print("DataSharing deployed at:", ds_address)

# Will add the other 2 contracts when they're ready







# Saving the deployed contract addresses to a local file (makes life easier for future tests)

deployment_data = {
    "ConsentManager": cm_address,
    "DataSharing": ds_address
}

import os

output_dir = "deployments/chain31337"
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# Save to a json file 
save_path = os.path.join(output_dir, "deployed_addresses.json")
with open(save_path, "w") as out_file:
    json.dump(deployment_data, out_file, indent=4)

#print(f"\nDeployment addresses written to {save_path}")