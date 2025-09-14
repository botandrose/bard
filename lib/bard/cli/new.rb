require "bard/cli/command"
require "bard/github"

class Bard::CLI::New < Bard::CLI::Command
  desc "new <project-name>", "creates new bard app named <project-name>"
  def new project_name
    @project_name = project_name
    validate
    create_project
    push_to_github
    stage
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
    run! <<~SH
      env -i bash -lc '
        export HOME=~
        cd ..
        source ~/.rvm/scripts/rvm
        rvm use --create #{ruby_version}@#{project_name}

        gem list rails -i || gem install rails --no-document
        rails new #{project_name} --skip-git --skip-kamal --skip-test -m #{template_path}
      '
    SH
  end

  def push_to_github
    api = Bard::Github.new(project_name)
    api.create_repo
    run! <<~SH
      cd ../#{project_name}
      git init -b master
      git add -A
      git commit -m"initial commit."
      git remote add origin git@github.com:botandrosedesign/#{project_name}
      git push -u origin master
    SH
    api.add_master_key File.read("../#{project_name}/config/master.key")
    api.add_master_branch_protection
    api.patch(nil, allow_auto_merge: true)
  end

  def stage
    run! <<~SH
      cd ../#{project_name}
      bard deploy --clone
    SH
  end

  def ruby_version
    "ruby-3.4.2"
  end

  def template_path
    File.expand_path("new_rails_template.rb", __dir__)
  end
end

