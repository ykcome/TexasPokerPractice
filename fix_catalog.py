from pbxproj import XcodeProject

project_path = "TexasPoker.xcodeproj/project.pbxproj"
project = XcodeProject.load(project_path)

# Enable String Catalogs for all configurations
for obj in project.objects.get_configurations_on_targets():
    obj.buildSettings["LOCALIZATION_PREFERS_STRING_CATALOGS"] = "YES"

# Set default language
root_object = project.objects[project.rootObject]
root_object["developmentRegion"] = "zh-Hans"

project.save()
print("Fixed project settings.")
