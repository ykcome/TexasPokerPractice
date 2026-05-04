import json, glob, os

files = []
for root, dirs, filenames in os.walk(os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")):
    for filename in filenames:
        if filename.endswith(".json") and "handhistory" in filename:
            files.append(os.path.join(root, filename))

files.sort(key=os.path.getmtime, reverse=True)
latest_files = files[:3]

for f in latest_files:
    print(f"--- File: {os.path.basename(f)} ---")
    with open(f, 'r') as file:
        data = json.load(file)
        if 'actions' not in data: continue
        for a in data['actions']:
            print(f"{a['phase']:<8} {a['playerName']:<10} {a['action']:<10} amt: {a.get('amount', 0)}")
