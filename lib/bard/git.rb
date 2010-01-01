module BardGit
  private
    def current_branch
      ref = `git symbolic-ref HEAD 2>&1`.chomp
      return false if ref =~ /^fatal:/
      ref.sub(/refs\/heads\//, '') # refs/heads/master ... we want "master"
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

