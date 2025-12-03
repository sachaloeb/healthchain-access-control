import json

with open("results/simulation_1000x100.json") as f:
    data = json.load(f)

successful = [d for d in data if "gasUsed" in d]
avg_gas = sum(d["gasUsed"] for d in successful) / len(successful)
avg_time = sum(d["duration"] for d in successful) / len(successful)

print(f"Average Gas: {int(avg_gas)} | Avg Time: {round(avg_time, 4)}s over {len(successful)} txs")
