import os
import re

def patch_file(filepath, replacements):
    if not os.path.exists(filepath):
        return
    with open(filepath, 'r') as f:
        content = f.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(filepath, 'w') as f:
        f.write(content)

# 1. TexasPokerApp.swift
patch_file('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/App/TexasPokerApp.swift', [
    ('.preferredColorScheme(.dark)', '.tint(.indigo) // Clean modern tool look')
])

# 2. MainTabView.swift
patch_file('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/UI/Views/MainTabView.swift', [
    ('.accentColor(.green)', '.tint(.indigo)')
])

# 3. HomeView.swift
patch_file('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/UI/Views/HomeView.swift', [
    ('Color(hex: "#121212")', 'Color(UIColor.systemGroupedBackground)'),
    ('.foregroundColor(.white)', '.foregroundColor(.primary)'),
    ('.background(Color.white.opacity(0.1))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)'),
    ('.background(Color.white.opacity(0.05))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)'),
    ('.foregroundColor(.yellow)', '.foregroundColor(.orange)') # yellow is hard to read on white
])

# 4. PlayerProfileView.swift
patch_file('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/UI/Views/PlayerProfileView.swift', [
    ('Color(hex: "#121212")', 'Color(UIColor.systemGroupedBackground)'),
    ('.foregroundColor(.white)', '.foregroundColor(.primary)'),
    ('.background(Color.white.opacity(0.05))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)'),
    ('Color.white.opacity(0.2)', 'Color.gray.opacity(0.2)')
])

# 5. SNGRecordDetailView.swift
patch_file('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/UI/Views/SNGRecordDetailView.swift', [
    ('Color(hex: "#121212")', 'Color(UIColor.systemGroupedBackground)'),
    ('.foregroundColor(.white)', '.foregroundColor(.primary)'),
    ('.background(Color.white.opacity(0.05))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)'),
    ('.background(Color.white.opacity(0.1))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)')
])

# 6. GameView.swift
patch_file('/Users/zhengliu/.openclaw/workspace/texaspoker/TexasPoker/Sources/UI/Views/GameView.swift', [
    ('Color(hex: "#1a472a")', 'Color(UIColor.systemGroupedBackground)'),
    ('.preferredColorScheme(.dark)', ''),
    ('.foregroundColor(.white.opacity(0.8))', '.foregroundColor(.secondary)'),
    ('.foregroundColor(.white.opacity(0.7))', '.foregroundColor(.secondary)'),
    ('.foregroundColor(.white)', '.foregroundColor(.primary)'),
    ('.background(Color.black.opacity(0.3))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n          .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)'),
    ('.background(Color.black.opacity(0.5))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)'),
    ('.background(Color.black.opacity(0.6))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)'),
    ('.background(Color.black.opacity(0.4))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)'),
    ('.background(Color.black.opacity(0.75))', '.background(Color(UIColor.secondarySystemGroupedBackground))\n                      .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)'),
    ('Color.white', 'Color.primary'),
    ('Color.black', 'Color.primary'), # If there are hardcoded black texts, maybe they need to be primary
    ('.foregroundColor(.yellow)', '.foregroundColor(.orange)') # Yellow on light mode is hard to see
])

print("Patch applied.")
