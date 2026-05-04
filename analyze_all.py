import json, glob, os

files = []
for root, dirs, filenames in os.walk(os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")):
    for filename in filenames:
        if filename.endswith(".json") and "handhistory" in filename.lower():
            files.append(os.path.join(root, filename))

for f in files:
    with open(f, 'r') as file:
        try:
            data = json.load(file)
        except:
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
