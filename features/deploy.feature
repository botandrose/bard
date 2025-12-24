Feature: bard deploy
  Deploy code changes to a remote server.

  Background:
    Given a test server is running

  Scenario: deploys code changes to the remote server
    Given I create a file "DEPLOYED.txt" with content "deployed by bard"
    And I commit the changes with message "Add deployed marker"
    When I run: bard deploy --skip-ci
    Then the output should contain "Deploy Succeeded"
    When I run: bard run "cat DEPLOYED.txt"
    Then the output should contain "deployed by bard"
