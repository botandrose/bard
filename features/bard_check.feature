Feature: Bard can check its environment for missing dependencies and potential problems

  Scenario: Bard check returns its version
    When I type "bard check -v"
    Then I should see the current version of bard
    And I should see the current version of git
    And I should see the current version of rubygems
    And I should see the current version of ruby

  Scenario: Bard check examines a local project for problems
    Given a shared rails project
    When I type "bard check"
    Then I should see "No problems"

  Scenario: Bard check detects missing database
    Given a shared rails project
    And the database is missing
    When I type "bard check"
    Then I should see the fatal error "missing database"
  
  Scenario: Bard check detects pending migrations
    Given a shared rails project
    And I have committed a set of changes that includes a new migration
    When I type "bard check"
    Then I should see the fatal error "pending migrations"

  Scenario: Bard check detects missing config/database.yml
    Given a shared rails project
    And "config/database.yml" is missing
    When I type "bard check"
    Then I should see the fatal error "missing config/database.yml"

  Scenario: Bard check detects missing submodules
    Given a shared rails project
    And a submodule
    And the submodule is missing
    When I type "bard check"
    Then I should see the fatal error "missing submodule"

  Scenario: Bard check detects submodules with detached heads
    Given a shared rails project
    And a submodule
    And the submodule has a detached head
    When I type "bard check"
    Then I should see the fatal error "submodule has a detached head"

  Scenario: Bard check detects missing gems
    Given a shared rails project
    And I have committed a set of changes that adds the test gem as a dependency
    And I dont have the test gem installed
    When I type "bard check"
    Then I should see the fatal error "missing gems"

  Scenario: Bard check detects master branch checked out
    Given a shared rails project
    And I am on the master branch
    When I type "bard check"
    Then I should see the fatal error "master branch"

  Scenario: Bard check detects missing integration branch
    Given a shared rails project
    And there is no integration branch
    When I type "bard check"
    Then I should see the fatal error "missing integration branch"

  Scenario: Bard check detects non-tracking integration branch
    Given a shared rails project
    And the integration branch isnt tracking origin/integration
    When I type "bard check"
    Then I should see the fatal error "tracking"

  Scenario: Bard check detects missing RAILS_ENV environment variable
    Given a shared rails project
    And my "RAILS_ENV" environment variable is ""
    When I type "bard check"
    Then I should see the warning "RAILS_ENV is not set"

  Scenario: Bard check detects missing staging hook
    Given a shared rails project
    And my "RAILS_ENV" environment variable is "staging"
    And there is no git hook on the staging server
    When I type "bard check" on the staging server
    Then I should see the fatal error "missing git hook"

  Scenario: Bard check detects unexecutable staging hook
    Given a shared rails project
    And my "RAILS_ENV" environment variable is "staging"
    And the git hook on the staging server is not executable
    When I type "bard check" on the staging server
    Then I should see the fatal error "unexecutable git hook"

  Scenario: Bard check detects improper staging hook
    Given a shared rails project
    And my "RAILS_ENV" environment variable is "staging"
    And the git hook on the staging server is bad
    When I type "bard check" on the staging server
    Then I should see the fatal error "improper git hook"

  Scenario: Bard check detects missing receive.denyCurrentBranch git variable on staging
    Given a shared rails project
    And my "RAILS_ENV" environment variable is "staging"
    And the staging server git config for receive.denyCurrentBranch is not "ignore"
    When I type "bard check" on the staging server
    Then I should see the fatal error "denyCurrentBranch"
