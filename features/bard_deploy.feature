Feature: Bard deploy should fold the integration branch into master and perform a deploy

  Scenario: Bard deploy detects non-fast-forward merge from integration to master
    Given a shared rails project
    And on development_b, a commit to the master branch
    And on development_b, I type "git push origin master"
    And a commit
    When I type "bard deploy"
    Then I should see the fatal error "Rebase"

  Scenario: Bard deploy works
    Given a shared rails project
    And a commit
    When I type "bard deploy"
    Then the "master" branch should match the "integration" branch
    And the "integration" branch should match the "origin/integration" branch
    And the "origin/master" branch should match the "origin/integration" branch

