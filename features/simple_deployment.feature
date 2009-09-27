Feature: Deployment for beginners
  Background:
    Given a shared test project

  Scenario: Starting a new bugfix correctly
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

  Scenario: Uploading local changes onto the integration branch
    Given I have committed a set of changes to my local integration branch
    When I type "bard push"
    Then the "integration" branch should match the "origin/integration" branch

  Scenario: Trying to bard push with dirty working directory
    Given I have committed a set of changes to my local integration branch
    And a dirty working directory
    When I type "bard push"
    Then I should see the fatal error "You have uncommitted changes!"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Trying to bard push with a non-fast-foward changeset
    Given I have committed a set of changes to my local integration branch
    And the remote integration branch has had a commit since I last pulled
    When I type "bard push"
    Then I should see the fatal error "Someone has pushed some changes"
    And the "integration" branch should not match the "origin/integration" branch

    #ensure fast-forward from current integration
    #stage integration HEAD
