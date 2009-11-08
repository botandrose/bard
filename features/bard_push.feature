Feature: bard push
  Background:
    Given a shared rails project

  Scenario: Uploading local changes onto the remote integration branch
    Given a commit
    When I type "bard push"
    Then the "integration" branch should match the "origin/integration" branch

  Scenario: Pushing a change that includes a migration
    Given on staging, a staging database
    And on staging, a test database
    And a commit with a new migration
    When I type "bard push"
    Then on staging, the staging database should include that migration
    And on staging, the test database should include that migration

  Scenario: Pushing a change that includes a gem dependency change
    Given I dont have the test gem installed
    And a commit that adds the test gem as a dependency
    When I type "bard push"
    Then on staging, the test gem should be installed

  Scenario: Pushing a change should advance the staging HEAD and restart the staging rails server
    Given a commit
    When I type "bard push"
    Then on staging, the directory should not be dirty
    And on staging, passenger should have been restarted

  Scenario: Pushing a change that includes a submodule addition
    Given a commit with a new submodule
    When I type "bard push"
    Then on staging, there should be one new submodule
    And the submodule branch should match the submodule origin branch
    And on staging, the submodule working directory should be clean
  
  Scenario: Pushing a change that includes a submodule update
    Given a submodule
    And a commit with a submodule update
    When I type "bard push"
    Then the submodule branch should match the submodule origin branch
    Then on staging, the submodule working directory should be clean

  Scenario: Pushing a change that includes a submodule url change
    Given a submodule
    And a commit with a submodule url change
    When I type "bard push"
    Then on staging, the submodule url should be changed
    And the submodule branch should match the submodule origin branch
    Then on staging, the submodule working directory should be clean

  # TODO
  #Scenario: Pushing a change that includes a submodule deletion
  #  Given a submodule
  #  Given I have committed a set of changes that includes a submodule deletion
  #  When I type "bard push"
  #  Then the remote submodule should be deleted

  Scenario: Trying to bard push when not in the project root
    Given I am in a subdirectory
    When I type "bard push"
    Then I should see the fatal error "root directory"

  Scenario: Trying to bard push when not on the integration branch
    Given a commit
    And I am on a non-integration branch
    When I type "bard push"
    Then I should see the fatal error "not on the integration branch"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Trying to bard push with a dirty working directory
    Given a commit
    And a dirty working directory
    When I type "bard push"
    Then I should see the fatal error "You have uncommitted changes!"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Trying to bard push with a non-fast-foward changeset
    Given a commit
    And on staging, a commit
    When I type "bard push"
    Then I should see the fatal error "Someone has pushed some changes"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Trying to bard push with an uncommitted change to a submodule
    Given a submodule
    And a commit
    And the submodule working directory is dirty
    When I type "bard push"
    Then I should see the fatal error "Micah"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Trying to bard push with a committed but unpushed change to a submodule
    Given a submodule
    And a commit to the submodule
    And a commit
    When I type "bard push"
    Then I should see the fatal error "Micah"
    And the "integration" branch should not match the "origin/integration" branch
