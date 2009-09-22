Feature: Deployment for beginners

  Scenario: Starting a new bugfix
    ensure clean working directory
    prompt for branch_name if none specified
    branch from origin/master into "bugfix-#{branch_name}"
  Scenario: Deploying a new bugfix
    ensure clean working directory
    ensure branch is bugfix-...
    ensure fast-forward from origin/master
    ensure tests pass via ci
    (ensure) fast-forward onto origin/master
    deploy
    delete bugfix-... branch
    checkout integration

  Scenario: Upload local changes onto the staging branch
    ensure clean working directory
    ensure fast-forward from current staging
    stage
