import json, glob, os

files = []
for root, dirs, filenames in os.walk(os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")):
    for filename in filenames:
        if filename.endswith(".json") and "handhistory" in filename:
            files.append(os.path.join(root, filename))

files.sort(key=os.path.getmtime, reverse=True)
latest_files = files[:10]

for f in latest_files:
    with open(f, 'r') as file:
        try:
            data = json.load(file)
        except Exception as e:
            continue
            
        if 'actions' not in data: continue
        actions = data['actions']
        
        last_player = None
        for i, action in enumerate(actions):
            player = action.get('playerName')
            phase = action.get('phase')
            
            if player == last_player:
                print(f"File: {os.path.basename(f)}")
                print(f"  Consecutive action by {player} in {phase}!")
                print(f"    Prev: {actions[i-1]}")
                print(f"    Curr: {action}")
            last_player = player
            
print("Done.")
