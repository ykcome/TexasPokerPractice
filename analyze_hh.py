import json, glob, os

files = []
for root, dirs, filenames in os.walk(os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")):
    for filename in filenames:
        if filename.endswith(".json") and "handhistory" in filename.lower():
            files.append(os.path.join(root, filename))

files.sort(key=os.path.getmtime, reverse=True)
latest_files = files[:10]

print(f"Found {len(files)} files, analyzing latest 10...")

for f in latest_files:
    with open(f, 'r') as file:
        try:
            data = json.load(file)
        except Exception as e:
            continue
            
        if 'actions' not in data: continue
        actions = data['actions']
        
        last_player = None
        last_phase = None
        for i, action in enumerate(actions):
            player = action.get('playerName')
            phase = action.get('phase')
            
            if player == last_player and phase == last_phase:
                print(f"File: {os.path.basename(f)}")
                print(f"  Violation! {player} acted twice in {phase}:")
                if i > 0: print(f"    Previous: {actions[i-1]}")
                print(f"    Current:  {action}")
            
            last_player = player
            last_phase = phase
            
print("Analysis complete.")
