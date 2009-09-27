Grit::Repo.class_eval do
  def remote_branches(remote = "origin")
    branches = self.remotes
    branches.reject!  { |r| r.name !~ %r(^#{remote}/) }
    branches.collect! { |r| r.name.split('/')[1] }
    branches.reject!  { |b| b == "HEAD" }
  end
end
