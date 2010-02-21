# bard.rb
# bot and rose design rails template
load_template "../bard_template/helper.rb"

%w(initial testing exception_notifier static_pages adva).each do |template|
  load_template "../bard_template/#{template}.rb"
end
run "cap stage"
