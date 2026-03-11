require 'xcodeproj'

project_path = '/Users/louis/Desktop/Slide/Slide.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add the files to the group (assuming 'Slide' group exists)
group = project.main_group.find_subpath(File.join('Slide'), true)

hud_manager_ref = group.new_file('HUDManager.swift')
settings_view_ref = group.new_file('SettingsView.swift')

# Add the file references to the target's source build phase
target.source_build_phase.add_file_reference(hud_manager_ref)
target.source_build_phase.add_file_reference(settings_view_ref)

project.save
puts "Successfully added files to Xcode project."
