Feature: Composer editor keyboard shortcuts
  The rich-text editor maps shortcuts to Twake Mail's own dialogs
  instead of the embedded editor's native ones.

  @NR-COMPOSER-001 @P2 @web @src:issue-4488 @src:pr-4539
  Scenario: the insert link shortcut opens the custom link dialog
    Given bob has opened a new composer
    When bob presses the insert link shortcut in the editor
    Then the custom insert link dialog is shown
