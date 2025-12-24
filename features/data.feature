Feature: bard data
  Copy database from a remote server to local.

  Background:
    Given a test server is running

  Scenario: copies database from production to local
    When I run: bard data
    Then the output should contain "Dumping production database to file"
    And the output should contain "Transfering file from production to local"
    And the output should contain "Loading file into local database"
    And a file "db/data.sql.gz" should exist locally
