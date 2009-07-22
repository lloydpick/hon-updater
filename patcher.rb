require 'net/http'
require 'fileutils'
require 'rubygems'
require 'zip/zip'

# Placeholder variables
version = "0.1.3.0"
server = "patch1.hon.s2games.com"
files_changed = []

# Functions
def unzip_file(file, destination)
  Zip::ZipFile.open(file) { |zip_file|
   zip_file.each { |f|
     f_path=File.join(destination, f.name)
     FileUtils.mkdir_p(File.dirname(f_path))
     zip_file.extract(f, f_path) unless File.exist?(f_path)
   }
  }
end


puts ""
puts "Heroes of Newerth Patch Grabber"
puts "==============================="

unless ARGV.length > 0
  puts "ERROR: Patch version not provided\n\n"
  exit
end

requested_version = ARGV.to_s
puts "Requested version...\t#{requested_version}"
print "Fetching manifest..."

manifest_file = "manifest-#{requested_version}.xml"

Net::HTTP.start(server) { |http|
  resp = http.get("/wac/i686/#{requested_version}/manifest.xml.zip")
  if resp.response.code.to_i == 200
    open("#{manifest_file}.zip", "wb") { |file|
      file.write(resp.body)
    }
    `unzip -qq -o #{manifest_file}.zip`
    File.delete("#{manifest_file}.zip")
    File.rename("manifest.xml", "#{manifest_file}")
  else
    print "\tFAILED!\n\nManifest file missing - 404\n"
    exit
  end
}
print "\tDone!\n"

counter = 1
print "Reading manifest...\t"
file = File.new(manifest_file, "r")
while (line = file.gets)
  # Get manifest line
  if counter == 2
    version = line.split("version=\"")[1].split("\"")[0]
  elsif line != "</manifest>"
    file_version = line.split("version=\"")
    if file_version[1]
      file_version = file_version[1].split("\"")
      file_version = file_version[0]
      if file_version == version
        changed = line.split("path=\"")
        changed = changed[1].split("\"")
        files_changed << changed[0]
      end
    end
  end
  #puts "#{counter}: #{line}"
  counter = counter + 1
end
file.close
puts "Done!\n\n"

short_version = version.split(".0")[0]
puts "Downloading files..."

Net::HTTP.start(server) { |http|
  new_counter = 1
  files_changed.each do |file|
    # Parse URL
    url = URI.parse("http://#{server}/wac/i686/#{short_version}/#{file}.zip")

    # Get the folder out
    folder = url.path.split(File.basename(url.path))[0]
    
    # Make the folder if it doesnt exist
    FileUtils.mkdir_p ".#{folder}"

    # Download file
    print "#{new_counter}/#{files_changed.size} - #{"%.00f" % ((new_counter / files_changed.size.to_f) * 100)}% - #{url.path}"
    STDOUT.flush
    resp = http.get(url.path)
    print "."
    STDOUT.flush

    open(".#{url.path}", "wb") { |file|
      print "."
      STDOUT.flush
      file.write(resp.body)
    }

    print "."
    STDOUT.flush
    `unzip -o .#{url.path} -d .#{folder}`

    print "."
    STDOUT.flush
    
    File.delete(".#{url.path}")
    print ". Done!\n"

    new_counter = new_counter + 1
  end
}