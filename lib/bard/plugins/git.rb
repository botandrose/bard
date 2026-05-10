module Bard
  module Git
    module_function

    def current_branch
      ref = `git symbolic-ref HEAD 2>&1`.chomp
      return false if ref =~ /^fatal:/
      ref.sub(/refs\/heads\//, '') # refs/heads/master ... we want "master"
    end

    def fast_forward_merge?(root, branch)
      root_head = sha_of(root)
      branch_head = sha_of(branch)
      common_ancestor = `git merge-base #{root_head} #{branch_head}`.chomp
      common_ancestor == root_head
    end

    def up_to_date_with_remote? branch
      sha_of(branch) == sha_of("origin/#{branch}")
    end

    def sha_of ref
      sha = `git rev-parse #{ref} 2>/dev/null`.chomp
      return sha if $?.success?
      nil # Branch doesn't exist
    end

    def in_linked_worktree?
      git_dir = `git rev-parse --git-dir 2>/dev/null`.chomp
      common_dir = `git rev-parse --git-common-dir 2>/dev/null`.chomp
      return false if git_dir.empty? || common_dir.empty?
      File.expand_path(git_dir) != File.expand_path(common_dir)
    end
  end
end

