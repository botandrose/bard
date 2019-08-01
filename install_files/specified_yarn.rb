module SpecifiedYarn
  extend self

  YARN_PATH = "node_modules/yarn/bin/yarn"

  def ensure!
    install_yarn unless yarn_installed?
    install_binstub unless binstub_installed?
    "bin/yarn install"
  end

  private

  def install_yarn
    system(". ~/.nvm/nvm.sh && npm install yarn@#{version} --no-save")
  end

  def install_binstub
    system("cd bin && ln -s ../#{YARN_PATH}")
  end

  def yarn_installed?
    File.exist?(YARN_PATH) && `#{YARN_PATH} --version`.chomp == version
  end

  def binstub_installed?
    File.exist?("bin/yarn")
  end

  def version
    File.read("package.json")[/"yarn": "([0-9\.]+)"/, 1]
  end
end

