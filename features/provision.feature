@provision
Feature: bard provision
  Background:
    Given a provision server is running

  Scenario: provisions a server with nginx reverse proxy
    When I provision the system
    And I set up the test project
    And I provision the app
    Then nginx should be installed on the server
    And the nginx config should contain "proxy_pass http://puma"
    And the nginx config should not contain "passenger"
