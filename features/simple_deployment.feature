Feature: Deployment for beginners
  Background:
    Given a shared test project

  Scenario: Starting a new bugfix correctly
    When I type "thor git:bugfix:new typo"
    Then I should be on the "bugfix-typo" branch
    And the "bugfix-typo" branch should match the "origin/master" branch

  Scenario: Starting a new bugfix with a dirty working tree
    When I type "thor git:bugfix:new typo"

    #check for current bard gem
    #ensure clean working directory
    #prompt for branch_name if none specified
    #branch from origin/master into "bugfix-#{branch_name}"

  Scenario: Deploying a new bugfix
    #check for current bard gem
    #ensure clean working directory
    #ensure branch is bugfix-...
    #ensure fast-forward from origin/master
    #ensure tests pass via ci
    #(ensure) fast-forward onto origin/master
    #deploy
    #delete bugfix-... branch
    #checkout integration HEAD

  Scenario: Upload local changes onto the integration branch
    #check for current bard gem
    #ensure clean working directory
    #ensure fast-forward from current integration
    #push
    #stage integration HEAD
