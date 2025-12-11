@podman
Feature: bard run against a podman TestContainers host
  Background:
    Given a podman testcontainer is ready for bard

  Scenario: Running ls via bard run
    Given a remote file "test-file.txt" exists in the test container
    When I run bard "ls" against the test container
    Then the bard command should succeed
    And the bard output should include "test-file.txt"

  Scenario: Running commands in isolated containers
    Given a remote file "another-file.txt" containing "content" exists in the test container
    When I run bard "cat another-file.txt" against the test container
    Then the bard command should succeed
    And the bard output should include "content"
