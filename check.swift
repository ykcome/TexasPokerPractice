import Foundation

let path = "Sources/GameLogic/GameManager.swift"
let content = try! String(contentsOfFile: path, encoding: .utf8)
let regex = try! NSRegularExpression(pattern: "String\\(localized:\\s*\"([^\"]+)\"\\)")
let results = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
var matches = [String]()
for result in results {
    if let range = Range(result.range(at: 1), in: content) {
        matches.append(String(content[range]))
    }
}

let jsonPath = "Sources/Resources/Localizable.xcstrings"
let jsonData = try! Data(contentsOfFile: jsonPath)
let json = try! JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
let stringsDict = json["strings"] as! [String: Any]

var missing = [String]()
for m in matches {
    if m.range(of: "\\p{Han}", options: .regularExpression) != nil {
        if stringsDict[m] == nil {
            missing.append("Missing Key: \(m)")
        } else {
            let entry = stringsDict[m] as! [String: Any]
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            let en = locs["en"] as? [String: Any] ?? [:]
            let unit = en["stringUnit"] as? [String: Any] ?? [:]
            let val = unit["value"] as? String ?? ""
            if val.isEmpty || val == m {
                missing.append("Missing or Bad EN: \(m)")
            } else if val.range(of: "\\p{Han}", options: .regularExpression) != nil {
                missing.append("Chinese in EN: \(m) -> \(val)")
            }
        }
    }
}

if missing.isEmpty {
    print("SUCCESS: All GameManager Chinese strings have English translations!")
} else {
    print("ERRORS FOUND:")
    for m in missing {
        print(m)
    }
}
