require "bard/github"

# generate and install ssh public key into deploy keys
# add repo to known hosts
# clone repo

class Bard::Provision::Repo < Bard::Provision
  def call
    print "Repo:"
    if !already_cloned?
      if !can_clone_project?
        if !ssh_keypair?
          print " Generating keypair in ~/.ssh,"
          provision_server.run! "ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -q -N \"\"", home: true
        end
        print " Add public key to GitHub repo deploy keys,"
        title = "#{server.ssh_uri.user}@#{server.ssh_uri.host}"
        key = provision_server.run "cat ~/.ssh/id_rsa.pub", home: true
        Bard::Github.new(config.project_name).add_deploy_key title:, key:
      end
      print " Cloning repo,"
      provision_server.run! "git clone git@github.com:botandrosedesign/#{project_name}", home: true
    else
      if !on_latest_master?
        print " Updating to latest master,"
        update_to_latest_master!
      end
    end

    puts " ✓"
  end

  private

  def ssh_keypair?
    provision_server.run "[ -f ~/.ssh/id_rsa.pub ]", home: true, quiet: true
  end

  def already_cloned?
    provision_server.run "[ -d ~/#{project_name}/.git ]", home: true, quiet: true
  end

  def can_clone_project?
    github_url = "git@github.com:botandrosedesign/#{project_name}"
    provision_server.run [
      "needle=$(ssh-keyscan -t ed25519 github.com 2>/dev/null | cut -d \" \" -f 2-3)",
      "grep -q \"$needle\" ~/.ssh/known_hosts || ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null",
      "git ls-remote #{github_url}",
    ].join("; "), home: true, quiet: true
  end

  def project_name
    config.project_name
  end

  def on_latest_master?
    provision_server.run [
      "cd ~/#{project_name}",
      "git fetch origin",
      "[ $(git rev-parse HEAD) = $(git rev-parse origin/master) ]"
    ].join(" && "), home: true, quiet: true
  end

  def update_to_latest_master!
    provision_server.run! [
      "cd ~/#{project_name}",
      "git checkout master",
      "git reset --hard origin/master"
    ].join(" && "), home: true
  end
end

