Feature: bard run
  Execute commands on a remote server.

  Background:
    Given a test server is running

  Scenario: executes a command on the remote server
    When I run: bard run "echo hello"
    Then the output should contain "hello"

  Scenario: operates in the configured path
    When I run: bard run "pwd"
    Then the output should contain "testproject"
