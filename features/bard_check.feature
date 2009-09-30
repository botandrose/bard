Feature: Bard can check its environment for missing dependencies and potential problems

  Scenario: Bard check returns its version
    When I type "bard check"
    Then I should see the current version of bard
    And I should see the current version of git
    And I should see the current version of rubygems
    And I should see the current version of ruby
