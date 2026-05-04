import json

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
with open(xcstrings_path, "r", encoding='utf-8') as f:
    data = json.load(f)

keys_to_add = {
    "商品未找到，请检查 App Store Connect 配置": "Product not found, please check App Store Connect configuration",
    "商品加载失败：\\(error.localizedDescription)": "Failed to load product: \\(error.localizedDescription)",
    "购买失败：\\(error.localizedDescription)": "Purchase failed: \\(error.localizedDescription)",
    "同步失败：\\(error.localizedDescription)": "Sync failed: \\(error.localizedDescription)"
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

print("Store error translations added.")
