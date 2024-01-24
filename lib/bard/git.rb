module Bard::CLI::Git
  module_function

  def current_branch
    ref = `git symbolic-ref HEAD 2>&1`.chomp
    return false if ref =~ /^fatal:/
    ref.sub(/refs\/heads\//, '') # refs/heads/master ... we want "master"
  end

  def current_sha
    sha_of("HEAD")
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
    `git rev-parse #{ref}`.chomp
  end
end

