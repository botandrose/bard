Feature: bard bugfix
  Background:
    Given a shared test project

  Scenario: Starting a new bugfix
    When I type "bard bugfix:new typo"
    Then I should be on the "bugfix-typo" branch
    And the "bugfix-typo" branch should match the "origin/master" branch

  Scenario: Starting a new bugfix with a dirty working directory
    Given a dirty working directory
    When I type "bard bugfix:new typo"
    Then I should see the fatal error "You have uncommitted changes!"
    And there should not be a "bugfix-typo" branch

  #Scenario: Deploying a new bugfix
    #check for current bard gem
    #ensure clean working directory
    #ensure branch is bugfix-...
    #ensure fast-forward from origin/master
    #ensure tests pass via ci
    #(ensure) fast-forward onto origin/master
    #deploy
    #rebase bugfix onto origin/integration
    #push to origin/integration
    #delete bugfix-... branch
    #checkout integration HEAD

