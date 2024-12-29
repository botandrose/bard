require "bard/cli/command"

class Bard::CLI::New < Bard::CLI::Command
  desc "new <project-name>", "creates new bard app named <project-name>"
  def new project_name
    @project_name = project_name
    validate
    create_project
    puts green("Project #{project_name} created!")
    puts "Please cd ../#{project_name}"
  end

  attr_accessor :project_name

  private

  def validate
    if project_name !~ /^[a-z][a-z0-9]*\Z/
      puts red("!!! ") + "Invalid project name: #{yellow(project_name)}."
      puts "The first character must be a lowercase letter, and all following characters must be a lowercase letter or number." 
      exit 1
    end
  end

  def create_project
    run! <<~BASH
      env -i bash -lc '
        export HOME=~
        cd ..
        source ~/.rvm/scripts/rvm
        rvm use --create #{ruby_version}@#{project_name}

        gem list rails -i && gem install rails --no-document
        rails new #{project_name} --skip-kamal -m #{template_path}
      '
    BASH
  end

  def ruby_version
    File.read(".ruby-version").chomp
  end

  def template_path
    File.expand_path("new_rails_template.rb", __dir__)
  end
end

