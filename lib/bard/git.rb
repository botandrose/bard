module BardGit
  private
    def ensure_integration_branch!
      return if `git name-rev --name-only HEAD`.chomp == "integration"
      fatal "You are not on the integration branch! Type `git checkout integration` to switch to it. If you have made changes to your current branch, please see Micah for assistance."
    end

    def ensure_clean_working_directory!
      return if`git status`.include? "working directory clean"
      fatal "Cannot upload changes: You have uncommitted changes!\n  Please run git commit before attempting to push or pull."
    end

    def fast_forward_merge? 
      run_crucial "git fetch origin"
      head = run_crucial "git rev-parse HEAD"
      remote_head = run_crucial "git rev-parse origin/integration"
      @common_ancestor = find_common_ancestor head, remote_head
      @common_ancestor == remote_head
    end

    def find_common_ancestor(head1, head2)
      run_crucial "git merge-base #{head1} #{head2}"
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
          branch = `git name-rev --name-only HEAD`.chomp
          `git fetch origin`
          submodule["id"] != `git rev-parse origin/#{branch}`.chomp
        end
      end
    end
end

