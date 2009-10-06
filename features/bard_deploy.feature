Feature: Bard deploy should fold the integration branch into master and perform a deploy

  Scenario: Bard deploy detects non-fast-forward merge from integration to master
    Given a shared rails project
    And the remote master branch has had a commit since I last pulled
    And I have committed a set of changes to my local integration branch
    When I type "bard deploy"
    Then I should see the fatal error "rebase"

  Scenario: Bard deploy works
    Given a shared rails project
    And I have committed a set of changes to my local integration branch
    When I type "bard deploy"
    Then the "master" branch should match the "integration" branch
    And the "integration" branch should match the "origin/integration" branch
    And the "origin/master" branch should match the "origin/integration" branch

