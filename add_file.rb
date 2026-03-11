require 'xcodeproj'
project = Xcodeproj::Project.open('Slide.xcodeproj')
target = project.targets.first

begin
    # In newer Xcode versions, synchronized groups don't support new_file directly.
    # But since it's a synchronized group, we just need the file on disk, Xcode picks it up automatically!
    puts 'Using synchronized group, no explicit add needed'
rescue => e
    puts "Error: #{e.message}"
end
