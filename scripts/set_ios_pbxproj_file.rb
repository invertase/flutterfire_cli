require 'xcodeproj'
require 'optparse'


options = {}
OptionParser.new do |parser|
  parser.banner = "Update project.pbxproj file for Xcode project."

  parser.on("-x", "--xcodeFile=XCODEFILE", String, "File path of [PROJECT NAME].xcodeproj for adding file") do |xcodeFile|
    options[:xcodeFile] = xcodeFile
  end
  
  parser.on("-g", "--googleFile=GOOGLEFILE", String, "File path for GoogleService-Info.plist to add to xcode project") do |googleFile|
    options[:googleFile] = googleFile
  end

end.parse!

# define the path to your .xcodeproj file
project_path = options[:xcodeFile]
# open the xcode project
project = Xcodeproj::Project.open(project_path)
# add GoogleService-Info.plist to your xcode project
file = project.new_file(options[:googleFile])
# save it
project.save

puts "Updated project.pbxproj file for Xcode project with GoogleService-Info.plist."