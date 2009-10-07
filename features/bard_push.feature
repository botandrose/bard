Feature: bard push
  Background:
    Given a shared rails project

  Scenario: Uploading local changes onto the remote integration branch
    Given I have committed a set of changes to my local integration branch
    When I type "bard push"
    Then the "integration" branch should match the "origin/integration" branch

  Scenario: Pushing a change that includes a migration
    Given I have committed a set of changes that includes a new migration
    And the staging server has a staging and test environment set up
    When I type "bard push"
    Then the both the staging and test databases should include that migration

  Scenario: Pushing a change that includes a gem dependency change
    Given I dont have the test gem installed
    And I have committed a set of changes that adds the test gem as a dependency
    When I type "bard push"
    Then the test gem should be installed

  Scenario: Pushing a change should advance the staging HEAD and restart the staging rails server
    Given I have committed a set of changes to my local integration branch
    When I type "bard push"
    Then the remote directory should not be dirty
    And the staging passenger should have been restarted

  Scenario: Pushing a change that includes a submodule addition
    Given I have committed a set of changes that includes a new submodule
    When I type "bard push"
    Then there should be one new submodule on the remote
    And the submodule branch should match the submodule origin branch
    Then the remote submodule working directory should be clean
  
  Scenario: Pushing a change that includes a submodule update
    Given a submodule
    And I have committed a set of changes that includes a submodule update
    When I type "bard push"
    Then the submodule branch should match the submodule origin branch
    Then the remote submodule working directory should be clean

  Scenario: Pushing a change that includes a submodule url change
    Given a submodule
    And I have committed a set of changes that includes a submodule url change
    When I type "bard push"
    Then the remote submodule url should be changed
    And the submodule branch should match the submodule origin branch
    Then the remote submodule working directory should be clean

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
    Given I have committed a set of changes to my local integration branch
    And I am on a non-integration branch
    When I type "bard push"
    Then I should see the fatal error "not on the integration branch"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Trying to bard push with a dirty working directory
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

  Scenario: Trying to bard push with an uncommitted change to a submodule
    Given a submodule
    And I have committed a set of changes to my local integration branch
    And the submodule working directory is dirty
    When I type "bard push"
    Then I should see the fatal error "Micah"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Trying to bard push with a committed but unpushed change to a submodule
    Given a submodule
    And I have committed a set of changes to the submodule
    And I have committed a set of changes to my local integration branch
    When I type "bard push"
    Then I should see the fatal error "Micah"
    And the "integration" branch should not match the "origin/integration" branch
