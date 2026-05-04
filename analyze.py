import json, glob, os

files = []
for root, dirs, filenames in os.walk(os.path.expanduser("~/Library/Developer/CoreSimulator/Devices")):
    for filename in filenames:
        if filename.endswith(".json") and "handhistory" in filename:
            files.append(os.path.join(root, filename))

files.sort(key=os.path.getmtime, reverse=True)
latest_files = files[:50]

human_wins = 0
ai_wins = 0
human_bluffs = 0
ai_folds_to_raise = 0

for f in latest_files:
    with open(f, 'r') as file:
        data = json.load(file)
        
        # Who won?
        if 'winners' in data:
            winners = data['winners']
            for w in winners:
                if '玩家' in w.get('name', ''):
                    human_wins += 1
                else:
                    ai_wins += 1
                    
        # Check actions
        if 'actions' in data:
            actions = data['actions']
            for i, action in enumerate(actions):
                # if human raised, and AI folded next
                if action.get('action') == 'RAISE' and '玩家' in action.get('playerName', ''):
                    if i + 1 < len(actions) and actions[i+1].get('action') == 'FOLD' and '玩家' not in actions[i+1].get('playerName', ''):
                        ai_folds_to_raise += 1

print(f"Analyzed {len(latest_files)} hands.")
print(f"Human wins: {human_wins}")
print(f"AI wins: {ai_wins}")
print(f"AI folds to human raise: {ai_folds_to_raise}")
