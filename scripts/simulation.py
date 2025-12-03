import json
import time
from web3 import Web3
from pathlib import Path

RPC_URL = "http://127.0.0.1:8545"
CHAIN_ID = 31337
w3 = Web3(Web3.HTTPProvider(RPC_URL))
assert w3.is_connected(), "Hardhat not running"

# Load deployed contract addresses
with open("deployments/chain31337/deployed_addresses.json") as f:
    addresses = json.load(f)

def load_abi(name):
    with open(f"artifacts/contracts/{name}.sol/{name}.json") as f:
        return json.load(f)["abi"]

ConsentManager = w3.eth.contract(
    address=addresses["ConsentManager"],
    abi=load_abi("ConsentManager")
)

raw_accounts = w3.eth.accounts[1:21]  # max allocated by hardhat we dont need to change this since its easier to reuse the same accounts
patients = (raw_accounts * 10)[:200]
doctors = (raw_accounts[::-1] * 10)[:200]


# Reuse accounts
if len(doctors) < 100:
    doctors *= (100 // len(doctors)) + 1
    doctors = doctors[:100]

data_ids = [w3.keccak(text=f"data_{i}") for i in range(3)]

results = []

print("Simulating...")

for i, patient in enumerate(patients):
    for j, doctor in enumerate(doctors):
        data_id = data_ids[(i + j) % len(data_ids)]
        try:
            start = time.time()
            tx = ConsentManager.functions.grantConsent(
                doctor,
                data_id,
                int(time.time()) + 3600,
                "scaling test"
            ).transact({"from": patient})
            receipt = w3.eth.wait_for_transaction_receipt(tx)
            duration = round(time.time() - start, 4)

            results.append({
                "patient": patient,
                "doctor": doctor,
                "gasUsed": receipt.gasUsed,
                "duration": duration
            })
        except Exception as e:
            results.append({
                "patient": patient,
                "doctor": doctor,
                "error": str(e)
            })

Path("results").mkdir(exist_ok=True)
with open("results/simulation_200x200.json", "w") as f:
    json.dump(results, f, indent=2)

print(f"Done. Results saved to results/")
