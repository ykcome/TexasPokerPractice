from pbxproj import XcodeProject
from pbxproj.pbxextensions.ProjectFiles import ProjectFiles
import os

ProjectFiles._FILE_TYPES['.xcstrings'] = ('text.json.xcstrings', 'PBXResourcesBuildPhase')

project_path = "TexasPoker.xcodeproj/project.pbxproj"
project = XcodeProject.load(project_path)

xcstrings_path = "Sources/Resources/Localizable.xcstrings"
os.makedirs(os.path.dirname(xcstrings_path), exist_ok=True)
if not os.path.exists(xcstrings_path):
    with open(xcstrings_path, "w") as f:
        f.write('{\n  "sourceLanguage" : "zh-Hans",\n  "strings" : {},\n  "version" : "1.0"\n}')

file_refs = project.get_files_by_path(xcstrings_path)
if not file_refs:
    # Add to Resources group and explicitly target the main target 'TexasPoker'
    project.add_file(xcstrings_path, parent=project.get_or_create_group('Resources'), target_name='TexasPoker')
    project.save()
    print("Added Localizable.xcstrings to project.")
else:
    print("Localizable.xcstrings already in project.")
