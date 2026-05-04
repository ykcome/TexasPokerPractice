import sys
import re
import uuid

proj_path = 'TexasPoker.xcodeproj/project.pbxproj'
with open(proj_path, 'r') as f:
    content = f.read()

# Instead of manually parsing, just put CircularImageCropper code into PlayerProfileView.swift
