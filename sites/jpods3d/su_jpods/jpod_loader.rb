# JPods Plugin Auto-Loader
# This file goes in the main Plugins folder (not inside JPods/) This is a duplicate.

require 'sketchup.rb'

# Guard: SketchUp auto-discovers JPods/main.rb directly, so this loader is only
# needed when that discovery does not fire. Skip if already loaded.
unless $jpods_main_loaded
  jpods_path = File.join(Sketchup.find_support_file('Plugins'), 'JPods', 'main.rb')

  if File.exist?(jpods_path)
    begin
      load jpods_path
      puts "✅ JPods plugin auto-loaded on startup"
    rescue => e
      puts "❌ Failed to auto-load JPods: #{e.message}"
    end
  else
    puts "⚠️ JPods main.rb not found at: #{jpods_path}"
  end
end