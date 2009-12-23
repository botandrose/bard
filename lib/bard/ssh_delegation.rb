class Bard < Thor
  desc "install-authorized-keys", "!!! INTERNAL USE ONLY !!! run as sudo"
  def install_authorized_keys(source_user, dest_user)
    source = "/home/#{source_user}/.ssh/authorized_keys"
    dest = "/home/#{dest_user}/.ssh/authorized_keys"

    file = File.read(source)
    file.gsub! /gitosis-serve/, "bard delegate"

    File.open(dest, "w") { |f| f.write(file) }
  end

  desc "delegate", "!!! INTERNAL USER ONLY !!!"
  def delegate(key)
    command = ENV['SSH_ORIGINAL_COMMAND']

    case command
    when /^scp -f (\w+)\.sql\.gz$/
      project = $1
      `#{command_for("staging", "cd #{project} && rake db:dump RAILS_ENV=staging && gzip -9f db/data.sql")}`
      command = "scp -f ~/#{project}/db/data.sql.gz"
    end

    exec command_for("staging", command)
  end

  private
    def command_for(user, command)
      %(sudo -H -u #{user} sh -c "cd ~ && #{command}")
    end
end
