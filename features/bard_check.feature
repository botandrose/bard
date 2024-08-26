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
    And a commit with a new migration
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
    And the test gem is not installed
    And a commit that adds the test gem as a dependency
    When I type "bard check"
    Then I should see the fatal error "missing gems"

  Scenario: Bard check detects master branch checked out
    Given a shared rails project
    And I am on the "master" branch
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

  Scenario: Bard check detects gitignored Capfile
    Given a shared rails project
    And the ".gitignore" file includes "Capfile"
    When I type "bard check"
    Then I should see the fatal error "Capfile should not be gitignored"

  Scenario: Bard check detects gitignored config/deploy.rb
    Given a shared rails project
    And the ".gitignore" file includes "config/deploy.rb"
    When I type "bard check"
    Then I should see the fatal error "config/deploy.rb should not be gitignored"

  Scenario: Bard check detects missing bard rake tasks
    Given a shared rails project
    And the "Rakefile" file does not include "bard/rake"
    When I type "bard check"
    Then I should see the fatal error "missing bard rake tasks"

  Scenario: Bard check detects missing bard cap tasks
    Given a shared rails project
    And the "Capfile" file does not include "bard/capistrano"
    When I type "bard check"
    Then I should see the fatal error "missing bard capistrano tasks"
