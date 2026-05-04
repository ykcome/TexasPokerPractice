require 'xcodeproj'
project_path = 'TexasPoker.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first
group = project.main_group.find_subpath(File.join('TexasPoker', 'Sources', 'UI', 'Views'), true)
file_reference = group.new_file('CircularImageCropper.swift')
target.add_file_references([file_reference])

project.save
