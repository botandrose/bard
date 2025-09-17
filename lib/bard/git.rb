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
      return sha if command_succeeded?
      nil # Branch doesn't exist
    end

    def command_succeeded?
      $?.success?
    end
  end
end

