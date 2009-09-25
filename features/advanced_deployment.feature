Feature: Deployment for advanced users

  Scenario: Starting a new feature
  Scenario: Sharing an existing feature
  Scenario: Merging an existing feature onto the integration branch for staging
  Scenario: Tagging an arbitrary commit to be staged
  Scenario: Deploying to production

  Scenario: Starting a new feature FEATURE
    check for current bard gem
    ensure clean working directory
    git fetch origin
    git checkout -b origin/master FEATURE
  Scenario: Sharing an existing feature
    check for current bard gem
    ensure clean working directory
    git remote branch publish

  Scenario: Deploying to production
    check for current bard gem
    ensure master is clean
    ensure origin/master is clean
    ensure master is fast-forward from origin/master
    push master to origin/master
    ssh to integration
      git reset --hard master
      git submodule init
      git submodule sync
      git submodule update
      rake gems:install
      rake db:migrate
      rake restart
    ensure production/master is clean
    ensure master is fast-forward from production/master
    ensure tests pass via ci
    ssh to production
      git pull origin/master
      git submodule init
      git submodule sync
      git submodule update
      rake gems:install
      rake db:migrate
      recompile sass to css
      rake asset:package nonsense
      rake restart
    reset --hard origin/integration to origin/master
