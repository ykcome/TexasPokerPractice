import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

bad_keys = []
for k, v in data["strings"].items():
    # Only care about Chinese keys
    has_chinese_key = any(char >= "\u4e00" and char <= "\u9fa5" for char in k)
    if not has_chinese_key:
        continue
    
    en_loc = v.get("localizations", {}).get("en", {})
    if not en_loc:
        bad_keys.append(f"MISSING EN BLOCK: {k}")
        continue
        
    en_val = en_loc.get("stringUnit", {}).get("value", "")
    if not en_val:
        bad_keys.append(f"EMPTY EN VALUE: {k}")
        continue
        
    if en_val == k:
        bad_keys.append(f"EN VALUE EQUALS CHINESE KEY: {k}")
        continue
        
    has_chinese_val = any(char >= "\u4e00" and char <= "\u9fa5" for char in en_val)
    if has_chinese_val:
        bad_keys.append(f"CHINESE CHAR IN EN VALUE: {k} -> {en_val}")

with open("report.txt", "w", encoding='utf-8') as f:
    f.write("\n".join(bad_keys))
