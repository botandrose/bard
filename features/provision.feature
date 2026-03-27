@provision
Feature: bard provision
  Background:
    Given a provision server is running

  Scenario: provisions a server with nginx reverse proxy
    When I provision the system
    And I set up the test project
    And I provision the app
    Then the site should be running
