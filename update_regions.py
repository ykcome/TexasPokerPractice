from pbxproj import XcodeProject
import sys

project_path = "TexasPoker.xcodeproj/project.pbxproj"
project = XcodeProject.load(project_path)

root_object = project.objects[project.rootObject]
if "knownRegions" in root_object:
    regions = root_object["knownRegions"]
    if "en" not in regions:
        regions.append("en")
    if "zh-Hans" not in regions:
        regions.append("zh-Hans")
else:
    root_object["knownRegions"] = ["en", "Base", "zh-Hans"]

project.save()
print("Updated knownRegions in project.pbxproj")
