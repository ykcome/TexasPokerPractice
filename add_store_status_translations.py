import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

keys_to_add = {
    "正在加载商品…": "Loading products...",
    "正在发起购买…": "Initiating purchase...",
    "正在验证交易…": "Verifying transaction...",
    "正在发放金币…": "Granting coins...",
    "正在完成交易…": "Completing transaction...",
    "已取消购买": "Purchase cancelled",
    "购买待处理…": "Purchase pending...",
    "正在同步购买…": "Syncing purchases..."
}

for k, eng_val in keys_to_add.items():
    if k not in data["strings"]:
        data["strings"][k] = {
            "extractionState": "manual",
            "localizations": {
                "en": {
                    "stringUnit": {
                        "state": "translated",
                        "value": eng_val
                    }
                }
            }
        }
    else:
        val = data["strings"][k]
        if "localizations" not in val:
            val["localizations"] = {}
        if "en" not in val["localizations"]:
            val["localizations"]["en"] = {}
        if "stringUnit" not in val["localizations"]["en"]:
            val["localizations"]["en"]["stringUnit"] = {}
            
        val["localizations"]["en"]["stringUnit"]["state"] = "translated"
        val["localizations"]["en"]["stringUnit"]["value"] = eng_val

with open(xcstrings_path, "w", encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Store status translations added.")
