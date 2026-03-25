require "bard/plugins/github"

class Bard::CLI
  NEW_RAILS_REQUIREMENT = "~> 8.1.0"

  desc "new <project-name>", "creates new bard app named <project-name>"
  method_option :skip_github, type: :boolean, default: false
  method_option :skip_stage, type: :boolean, default: false
  def new(project_name)
    @new_project_name = project_name
    new_validate
    new_create_project
    new_push_to_github unless options[:skip_github]
    new_stage unless options[:skip_stage]
    puts green("Project #{@new_project_name} created!")
    puts "Please cd ../#{@new_project_name}"
  end

  no_commands do
    def new_validate
      if @new_project_name !~ /^[a-z][a-z0-9]*\Z/
        puts red("!!! ") + "Invalid project name: #{yellow(@new_project_name)}."
        puts "The first character must be a lowercase letter, and all following characters must be a lowercase letter or number."
        exit 1
      end
    end

    def new_create_project
      run! new_build_create_project_script
    end

    def new_build_create_project_script
      new_build_bash_env do
        new_build_rvm_setup +
        new_build_gem_install("rails", NEW_RAILS_REQUIREMENT) +
        new_build_rails_new
      end
    end

    def new_build_bash_env
      script = yield
      <<~SH
        env -i bash -lc '
          export HOME=~
          source ~/.rvm/scripts/rvm
          #{script}
        '
      SH
    end

    def new_build_rvm_setup
      <<~SH
        cd ..
        rvm use --create #{new_ruby_version}@#{@new_project_name}
      SH
    end

    def new_build_gem_install(gem_name, version_requirement)
      <<~SH
        GEM_VERSION=$(gem install #{gem_name} -v "#{version_requirement}" --no-document 2>&1 | grep -oP "Successfully installed #{gem_name}-\\K[0-9.]+")
      SH
    end

    def new_build_rails_new
      <<~SH
        rails _${GEM_VERSION}_ new #{@new_project_name} --skip-git --skip-kamal --skip-test -m #{new_template_path}
      SH
    end

    def new_push_to_github
      api = Bard::Github.new(@new_project_name)
      api.create_repo
      run! <<~SH
        cd ../#{@new_project_name}
        git init -b master
        git add -A
        git commit -m"initial commit."
        git remote add origin git@github.com:botandrosedesign/#{@new_project_name}
        git push -u origin master
      SH
      api.add_master_key File.read("../#{@new_project_name}/config/master.key")
      api.add_master_branch_protection
      api.patch(nil, allow_auto_merge: true)
    end

    def new_stage
      run! <<~SH
        cd ../#{@new_project_name}
        bard deploy --clone
      SH
    end

    def new_ruby_version
      "ruby-4.0.2"
    end

    def new_template_path
      File.expand_path("new/rails_template.rb", __dir__)
    end
  end
end
