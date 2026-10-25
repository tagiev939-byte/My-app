import json, subprocess
out = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "-j"], capture_output=True, text=True).stdout
devs = json.loads(out)["devices"]
cands = []
for runtime, items in devs.items():
    if "iOS" not in runtime:
        continue
    for d in items:
        if d["name"].startswith("iPhone"):
            cands.append((runtime, d))
def score(c):
    name = c[1]["name"]
    pref = 0 if "Pro" in name and "Max" not in name else 1
    return (pref, -len(c[0]), c[0], name)
cands.sort(key=score)
best = cands[0]
print(best[1]["udid"])
