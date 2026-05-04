import json, glob, os

files = []
for root, dirs, filenames in os.walk(os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")):
    for filename in filenames:
        if filename.endswith(".json") and "handhistory" in filename:
            files.append(os.path.join(root, filename))

files.sort(key=os.path.getmtime, reverse=True)
if not files:
    print("No hand history files found.")
    exit(0)

with open(files[0], 'r') as file:
    data = json.load(file)
    if 'actions' in data:
        for a in data['actions']:
            print(f"{a['phase']:<8} {a['playerName']:<10} {a['action']:<10} amt: {a.get('amount', 0)}")
