Feature: bard pull
  Background:
    Given a shared test project
    And I am on the integration branch
    # TODO what about non-integration branch scenarios

  Scenario: Pulling down the latest changes from the remote integration branch
    Given the remote integration branch has had a commit since I last pulled
    When I type "bard pull"
    Then the "integration" branch should match the "origin/integration" branch

  Scenario: Pulling latest changes from the remote integration branch after committing locally
    Given the remote integration branch has had a commit since I last pulled
    And I have committed a set of changes to my local integration branch
    When I type "bard pull"
    Then I should see the warning "Someone has pushed some changes"
    And the "integration" branch should be a fast-forward from the "origin/integration" branch

  Scenario: Trying to bard pull with a dirty working directory
    Given the remote integration branch has had a commit since I last pulled
    And a dirty working directory
    When I type "bard pull"
    Then I should see the fatal error "You have uncommitted changes!"
    And the "integration" branch should not match the "origin/integration" branch

