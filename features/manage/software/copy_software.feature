
Feature: Copying software

  Background:
    Given I am Mike

  @personas @javascript @browser
  Scenario: Copying software
    Given a software license exists
    And this software license contains an attachment
    When I copy an existing software license
    Then it opens the edit view of the new software license
    And the title is labeled as "Create new software license"
    And the save button is labeled as "Save License"
    And a new inventory code is assigned
    When I save
    Then the new software license is created
    And the following fields were copied from the original software license
      | Software               |
      | Reference              |
      | Owner                  |
      | Responsible department |
      | Invoice Date           |
      | Initial Price          |
      | Supplier               |
      | Procured by            |
      | Note                   |
      | Activation type        |
      | License Type           |
      | Total quantity         |
      | Operating System       |
      | Installation           |
      | License expiration     |
      | Maintenance contract   |
      | Maintenance expiration |
      | Currency               |
      | Price                  |
    And the attachment has not been copied to the new software license

  @personas @javascript @browser
  Scenario: Where can software be copied
    Given a software license exists
    When I open the inventory
    Then I can copy an existing software license
    When I am editing an software license
    Then I can save and copy the existing software license
