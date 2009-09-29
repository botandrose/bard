Grit::Repo.class_eval do
  def remote_branches(remote = "origin")
    branches = self.remotes
    branches.reject!  { |r| r.name !~ %r(^#{remote}/) }
    branches.collect! { |r| r.name.split('/')[1] }
    branches.reject!  { |b| b == "HEAD" }
  end

  def submodules
    Grit::Submodule.config self, self.head.name
  end

  def find_common_ancestor(head1, head2)
    `git merge-base #{head1} #{head2}`.chomp
  end
end
