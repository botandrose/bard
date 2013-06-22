module Bard::CLI::Git
  private

  def current_branch
    ref = `git symbolic-ref HEAD 2>&1`.chomp
    return false if ref =~ /^fatal:/
    ref.sub(/refs\/heads\//, '') # refs/heads/master ... we want "master"
  end

  def current_sha
    `git rev-parse HEAD`.chomp
  end

  def fast_forward_merge?(root, branch)
    root_head = run_crucial "git rev-parse #{root}"
    branch_head = run_crucial "git rev-parse #{branch}"
    @common_ancestor = find_common_ancestor root_head, branch_head 
    @common_ancestor == root_head
  end

  def find_common_ancestor(head1, head2)
    run_crucial "git merge-base #{head1} #{head2}"
  end
end

