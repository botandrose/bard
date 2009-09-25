Feature: Deployment for advanced users

  Scenario: Starting a new feature
  Scenario: Sharing an existing feature
  Scenario: Merging an existing feature onto the integration branch for staging
  Scenario: Tagging an arbitrary commit to be staged
  Scenario: Deploying to production

  Scenario: Starting a new feature
    ensure clean working directory
    branch from current production
  Scenario: Sharing an existing feature
    ensure clean working directory
    git remote branch publish

  Scenario: Deploying to production
    ensure clean working directory
    ensure fast forward from current production
    ensure tests pass via ci
    deploy

