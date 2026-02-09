Feature: bard ci
  Run continuous integration tests.

  Background:
    Given a test server is running

  Scenario: no CI configured error
    When I run expecting failure: bard ci
    Then the output should contain "No CI found"
    And the output should contain "Re-run with --skip-ci to bypass CI"

  Scenario: local CI runs successfully
    Given a local CI script that passes
    When I run: bard ci --local-ci
    Then the output should contain "Continuous integration: starting build"
    And the output should contain "Continuous integration: success!"

  Scenario: local CI reports failure
    Given a local CI script that fails with "Test failed: expected 1 but got 2"
    When I run expecting failure: bard ci --local-ci
    Then the output should contain "Test failed: expected 1 but got 2"
    And the output should contain "Automated tests failed!"

  Scenario: --ci option runs specified CI runner
    Given a local CI script that passes
    When I run: bard ci --ci=local
    Then the output should contain "Continuous integration: starting build"
    And the output should contain "Continuous integration: success!"

  Scenario: --ci option reports failure from specified runner
    Given a local CI script that fails with "Custom runner failed"
    When I run expecting failure: bard ci --ci=local
    Then the output should contain "Custom runner failed"
    And the output should contain "Automated tests failed!"

  Scenario: deploy passes --ci option to CI
    Given a local CI script that passes
    And I create a file "ci-option-test.txt" with content "ci option test"
    And I commit the changes with message "Add CI option test file"
    When I run: bard deploy --ci=local
    Then the output should contain "Continuous integration: starting build"
    And the output should contain "Continuous integration: success!"
    And the output should contain "Deploy Succeeded"

  Scenario: deploy runs CI before deploying
    Given a local CI script that passes
    And I create a file "ci-test.txt" with content "ci test"
    And I commit the changes with message "Add CI test file"
    When I run: bard deploy --local-ci
    Then the output should contain "Continuous integration: starting build"
    And the output should contain "Continuous integration: success!"
    And the output should contain "Deploy Succeeded"

  Scenario: deploy aborts if CI fails
    Given a local CI script that fails with "Build failed"
    And I create a file "ci-fail.txt" with content "ci fail test"
    And I commit the changes with message "Add CI fail test file"
    When I run expecting failure: bard deploy --local-ci
    Then the output should contain "Continuous integration: starting build"
    And the output should contain "Build failed"
    And the output should contain "Automated tests failed!"
    And the output should not contain "Deploy Succeeded"
