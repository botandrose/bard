@new
Feature: bard new
  Create a new bard-managed Rails project.

  Background:
    Given a bard new server is running

  Scenario: creates a new Rails project
    When I run bard new "testproject"
    Then the output should contain "Project testproject created!"
    And the project "testproject" should run successfully
    And the project "testproject" should respond to http://testproject.localhost
