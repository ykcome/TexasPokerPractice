import json, glob, os

files = []
for root, dirs, filenames in os.walk(os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")):
    for filename in filenames:
        if filename.endswith(".json") and "handhistory" in filename.lower():
            files.append(os.path.join(root, filename))

files.sort(key=os.path.getmtime, reverse=True)
latest_files = files[:10]

for f in latest_files:
    try:
        with open(f, 'r') as file:
            data = json.load(file)
            
        action_seq = data.get('actionSequence', [])
        for round_data in action_seq:
            phase = round_data.get('phase')
            actions = round_data.get('actions', [])
            
            last_player = None
            last_action_type = None
            
            for i, action in enumerate(actions):
                player = action.get('playerId')
                act_type = action.get('action')
                
                # Ignore POST_SB / POST_BB / POST_ANTE for this check, as they are automatic
                # Actually, let's include them but note if it's POST_SB -> RAISE
                
                if player == last_player:
                    # Is it a real double action?
                    if last_action_type not in ["POST_SB", "POST_BB", "POST_ANTE"]:
                        print(f"\n[VIOLATION] File: {os.path.basename(f)} | Phase: {phase}")
                        print(f"  Prev Action: {actions[i-1]}")
                        print(f"  Curr Action: {action}")
                
                last_player = player
                last_action_type = act_type
                
    except Exception as e:
        print(f"Error reading {f}: {e}")
        
print("Analysis complete.")
