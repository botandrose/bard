Feature: bard deploy git workflow
  Git workflow behaviors during deploy.

  Background:
    Given a test server is running

  Scenario: deploy on master pushes unpushed commits
    Given I create a file "local-only.txt" with content "local commit"
    And I commit the changes with message "Add local only file"
    When I run: bard deploy --skip-ci
    Then the output should contain "Deploy Succeeded"
    When I run: bard run "cat local-only.txt"
    Then the output should contain "local commit"

  Scenario: feature branch fast-forward merge
    Given I create and switch to branch "feature-branch"
    And I create a file "feature.txt" with content "feature content"
    And I commit the changes with message "Add feature"
    When I run: bard deploy --skip-ci
    Then the output should contain "Deploy Succeeded"
    And I should be on branch "master"
    And branch "feature-branch" should not exist locally
    And branch "feature-branch" should not exist on origin
    When I run: bard run "cat feature.txt"
    Then the output should contain "feature content"

  Scenario: feature branch requires rebase
    Given I create and switch to branch "feature-branch"
    And I create a file "feature.txt" with content "feature content"
    And I commit the changes with message "Add feature"
    And master has an additional commit from another source
    When I run: bard deploy --skip-ci
    Then the output should contain "The master branch has advanced"
    And the output should contain "Attempting rebase"
    And the output should contain "Deploy Succeeded"
    And I should be on branch "master"
    When I run: bard run "cat feature.txt"
    Then the output should contain "feature content"
    When I run: bard run "cat remote-change.txt"
    Then the output should contain "remote change"

  Scenario: feature branch rebase conflict
    Given I create and switch to branch "feature-branch"
    And I create a file "conflict.txt" with content "feature content"
    And I commit the changes with message "Add conflicting file"
    And master has a conflicting commit to "conflict.txt"
    When I run expecting failure: bard deploy --skip-ci
    Then the output should contain "The master branch has advanced"
    And the output should contain "Attempting rebase"
    And the output should contain "Running command failed"

  Scenario: branch cleanup after deploy
    Given I create and switch to branch "cleanup-test"
    And I create a file "cleanup.txt" with content "cleanup test"
    And I commit the changes with message "Add cleanup test file"
    And I push branch "cleanup-test" to origin
    When I run: bard deploy --skip-ci
    Then the output should contain "Deleting branch: cleanup-test"
    And the output should contain "Deploy Succeeded"
    And I should be on branch "master"
    And branch "cleanup-test" should not exist locally
    And branch "cleanup-test" should not exist on origin

  Scenario: deploy a branch without checking it out
    Given I create and switch to branch "feature-branch"
    And I create a file "feature.txt" with content "feature content"
    And I commit the changes with message "Add feature"
    And I switch to branch "master"
    When I run: bard deploy feature-branch --skip-ci
    Then the output should contain "Deploy Succeeded"
    And I should be on branch "master"
    And branch "feature-branch" should not exist locally
    When I run: bard run "cat feature.txt"
    Then the output should contain "feature content"

  Scenario: deploy a branch that requires rebase without checking it out
    Given I create and switch to branch "feature-branch"
    And I create a file "feature.txt" with content "feature content"
    And I commit the changes with message "Add feature"
    And I switch to branch "master"
    And master has an additional commit from another source
    When I run: bard deploy feature-branch --skip-ci
    Then the output should contain "The master branch has advanced"
    And the output should contain "Attempting rebase"
    And the output should contain "Deploy Succeeded"
    And I should be on branch "master"
    When I run: bard run "cat feature.txt"
    Then the output should contain "feature content"
