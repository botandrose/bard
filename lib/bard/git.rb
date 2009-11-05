module BardGit
  private
    def ensure_project_root!
      fatal "You are not in the project's root directory!" unless File.directory? ".git"
    end

    def ensure_integration_branch!
      return if current_branch == "integration"
      fatal "You are not on the integration branch! Type `git checkout integration` to switch to it. If you have made changes to your current branch, please see Micah for assistance."
    end

    def ensure_clean_working_directory!
      return if`git status`.include? "working directory clean"
      fatal "Cannot upload changes: You have uncommitted changes!\n  Please run git commit before attempting to push or pull."
    end

    def current_branch
      ref = `git symbolic-ref HEAD 2>&1`.chomp
      return false if ref =~ /^fatal:/
      rev.split('/').last # /refs/heads/master ... we want "master"
    end

    def fast_forward_merge?(root = "origin/integration", branch = "HEAD")
      run_crucial "git fetch origin"
      root_head = run_crucial "git rev-parse #{root}"
      branch_head = run_crucial "git rev-parse #{branch}"
      @common_ancestor = find_common_ancestor root_head, branch_head 
      @common_ancestor == root_head
    end

    def find_common_ancestor(head1, head2)
      run_crucial "git merge-base #{head1} #{head2}"
    end

    def changed_files(old_rev, new_rev)
      run_crucial("git diff #{old_rev} #{new_rev} --diff-filter=ACMRD --name-only").split("\n") 
    end

    def submodule_dirty?
      @repo ||= Grit::Repo.new "."
      submodules = Grit::Submodule.config(@repo, @repo.head.name)
      submodules.any? do |name, submodule|
        Dir.chdir submodule["path"] do
          not `git status`.include? "working directory clean"
        end
      end
    end

    def submodule_unpushed?
      @repo ||= Grit::Repo.new "."
      submodules = Grit::Submodule.config(@repo, @repo.head.name)
      submodules.any? do |name, submodule|
        Dir.chdir submodule["path"] do
          `git fetch origin`
          submodule["id"] != `git rev-parse origin/#{current_branch}`.chomp
        end
      end
    end
end

