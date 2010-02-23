# bard.rb
# bot and rose design rails template
require "bard/template/helper"

%w(initial testing exception_notifier static_pages adva).each do |template_file|
  bard_load_template template_file
end
run "cd #{project_name}"
puts "Project #{project_name} created! Ask Micah to set up staging server."
