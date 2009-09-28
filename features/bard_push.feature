Feature: bard push
  Background:
    Given a shared test project
    # TODO what about non-integration branch scenarios

  Scenario: Uploading local changes onto the remote integration branch
    Given I have committed a set of changes to my local integration branch
    When I type "bard push"
    Then the "integration" branch should match the "origin/integration" branch

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
