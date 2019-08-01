module SpecifiedNode
  class NVMError < StandardError; end

  NVM_PATH = File.expand_path("~/.nvm/nvm.sh")

  extend self

  def ensure!
    install_nvm unless nvm_installed?
    restart unless nvm_active?
    install_node unless node_installed?
    "true"
  end

  private

  def install_nvm
    system("curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash")\
      or raise "Couldn't install nvm"
  end

  def nvm_installed?
    File.exist?(NVM_PATH)
  end

  def install_node
    nvm "install" or raise NVMError.new($?.exitstatus)
  end

  def node_installed?
    nvm "use"
  end

  def restart
    exec %(bash -lc ". #{NVM_PATH}; #{$0}")
  end

  def nvm_active?
    ENV.key?("NVM_DIR")
  end

  def nvm command
    system(". #{NVM_PATH}; nvm #{command}")
  end
end
