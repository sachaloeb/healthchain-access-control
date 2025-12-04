from web3 import Web3
import json
import time

# Connecting to the local Hardhat node
provider_url = "http://127.0.0.1:8545"
w3 = Web3(Web3.HTTPProvider(provider_url))

if not w3.is_connected():
    raise Exception("Cant reach hardhat node. Is it running?")

with open("./deployments/chain31337/deployed_addresses.json", "r") as cm_address:
    addresses = json.load(cm_address)

# Load the ABI for ConsentManager
with open("./artifacts/contracts/ConsentManager.sol/ConsentManager.json", "r") as abi_file:
    cm_json = json.load(abi_file)

consent_abi = cm_json["abi"]
cm_addr = addresses["ConsentManager"]
consent_mgr = w3.eth.contract(address=cm_addr, abi=consent_abi)

# Dummy accounts
user_patient = w3.eth.accounts[1]
assigned_doctor = w3.eth.accounts[2]

# Just using a hash of a string to simulate a data identifier (not super clean, but works) 
# Note: Off-chain data?
lab_data_id = w3.keccak(text="blood_test")

# Patient grants consent
print("\nNow granting consent...") # Note: Do we say clinicians in general or 
                                #IdentityRegistry gives the type of data requester (doctor, researcher, insurance provider)?

# Patient allows access for 300s (5 minutes)
expiry_time = int(time.time()) + 300
consent_reason = "diagnosis"
grant_txn = consent_mgr.functions.grantConsent(
    assigned_doctor,
    lab_data_id,
    expiry_time,
    consent_reason
).transact({"from": user_patient})

grant_receipt = w3.eth.wait_for_transaction_receipt(grant_txn)
print("Consent granted. Tx hash:", grant_receipt.transactionHash.hex())

# Check if consent is valid
print("\nVerifying if consent is valid...")

valid, consent_id = consent_mgr.functions.isConsentValid(
    user_patient,
    assigned_doctor,
    lab_data_id
).call()

print("Is valid:", valid)
print("Consent ID:", consent_id)

# Log access 
print("Logging access...")
access_txn = consent_mgr.functions.logAccess(consent_id).transact({"from": assigned_doctor})
w3.eth.wait_for_transaction_receipt(access_txn)
print("Access successfully logged.")

# Patient revokes consent
print("\nNow revoking consent...")
revoke_txn = consent_mgr.functions.revokeConsent(consent_id).transact({"from": user_patient})
w3.eth.wait_for_transaction_receipt(revoke_txn)
print("Consent has been revoked")

# Check validity
print("\nRunning one last check on consent validity...")

is_still_valid, _ = consent_mgr.functions.isConsentValid(
    user_patient,
    assigned_doctor,
    lab_data_id
).call()

print("Valid after revocation?", is_still_valid)
