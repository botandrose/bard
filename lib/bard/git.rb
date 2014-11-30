module Bard::CLI::Git
  module_function

  def current_branch
    ref = `git symbolic-ref HEAD 2>&1`.chomp
    return false if ref =~ /^fatal:/
    ref.sub(/refs\/heads\//, '') # refs/heads/master ... we want "master"
  end

  def current_sha
    `git rev-parse HEAD`.chomp
  end

  def fast_forward_merge?(root, branch)
    root_head = `git rev-parse #{root}`.chomp
    branch_head = `git rev-parse #{branch}`.chomp
    common_ancestor = `git merge-base #{root_head} #{branch_head}`.chomp
    common_ancestor == root_head
  end
end

