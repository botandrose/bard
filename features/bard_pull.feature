Feature: bard pull
  Background:
    Given a shared rails project

  Scenario: Pulling down the latest changes from the remote integration branch
    Given the remote integration branch has had a commit since I last pulled
    When I type "bard pull"
    Then the "integration" branch should match the "origin/integration" branch

  Scenario: Pulling down when the latest changes include a submodule addition
    Given the remote integration branch has had a commit that includes a new submodule
    When I type "bard pull"
    Then the "integration" branch should match the "origin/integration" branch
    And there should be one new submodule
    And the submodule branch should match the submodule origin branch
    And the submodule working directory should be clean

  Scenario: Pulling down when the latest changes include a submodule update
    Given a submodule
    And the remote integration branch has had a commit that includes a submodule update
    When I type "bard pull"
    Then the "integration" branch should match the "origin/integration" branch
    And the submodule branch should match the submodule origin branch
    And the submodule working directory should be clean

  Scenario: Pulling down when the latest changes include a submodule url change
    Given a submodule
    And the remote integration branch has had a commit that includes a submodule url change
    When I type "bard pull"
    Then the "integration" branch should match the "origin/integration" branch
    And the submodule url should be changed
    And the submodule branch should match the submodule origin branch
    And the submodule working directory should be clean

  # TODO
  #Scenario: Pulling down when the latest changes include a submodule deletion
  #  Given a submodule
  #  And the remote integration branch has had a commit that includes a submodule deletion
  #  When I type "bard pull"
  #  Then the "integration" branch should match the "origin/integration" branch
  #  And the submodule should be deleted

  Scenario: Pulling latest changes from the remote integration branch after committing locally
    Given the remote integration branch has had a commit since I last pulled
    And I have committed a set of changes to my local integration branch
    When I type "bard pull"
    Then I should see the warning "Someone has pushed some changes"
    And the "integration" branch should be a fast-forward from the "origin/integration" branch

  Scenario: Trying to bard pull when not in the project root
    Given I am in a subdirectory
    When I type "bard pull"
    Then I should see the fatal error "root directory"

  Scenario: Trying to bard pull with a dirty working directory
    Given the remote integration branch has had a commit since I last pulled
    And a dirty working directory
    When I type "bard pull"
    Then I should see the fatal error "You have uncommitted changes!"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Trying to bard pull when not on the integration branch
    Given the remote integration branch has had a commit since I last pulled
    And I am on a non-integration branch
    When I type "bard pull"
    Then I should see the fatal error "not on the integration branch"
    And the "integration" branch should not match the "origin/integration" branch

  Scenario: Pulling in a change that includes a migration on a dev machine
    Given the remote integration branch has had a commit that includes a new migration
    And I have a development environment set up locally
    When I type "bard pull"
    Then the development database should include that migration

  Scenario: Pulling in a change that includes a migration on a dev and testing machine
    Given the remote integration branch has had a commit that includes a new migration
    And I have development and test environments set up locally
    When I type "bard pull"
    Then both the development and test databases should include that migration

  Scenario: Pulling in a change that includes a gem dependency change
    Given I dont have the test gem installed
    And the remote integration branch has had a commit that adds the test gem as a dependency
    When I type "bard pull"
    Then the test gem should be installed

  Scenario: Pulling in a change should restart the rails server
    Given the remote integration branch has had a commit since I last pulled
    When I type "bard pull"
    Then passenger should have been restarted
