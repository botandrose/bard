Feature: bard core functionality smoke tests
  These are end-to-end smoke tests that verify the basic happy paths work
  against a real SSH server running in a container.

  Background:
    Given a test server is running

  Scenario: bard run executes a command on the remote server
    When I run: bard run "echo hello"
    Then it should succeed
    And the output should contain "hello"

  Scenario: bard run operates in the configured path
    When I run: bard run "pwd"
    Then it should succeed
    And the output should contain "testproject"
