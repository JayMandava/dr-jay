# Surroundings copy and Settings spacing

Based on merged main `198238b`.

- Keep the Settings disclosure to the action, recipient and data shared.
  The bundled Privacy Policy retains the storage, precision and scoring details.
- Keep the card footer to optional participation, the separate daily bonus cap
  and personal fluid/dietary guidance. Shorten all five suggestion descriptions.
- Use a short completion button label, with an accessible name that includes
  its visible wording and identifies the suggestion.
- Give all nine Form section footers in Settings and its Theme screen the same
  8-point leading inset. This is a visual neatness choice, not a claim of
  improved comprehension. Leading padding respects layout direction; semantic
  fonts, wrapping, contrast and reading order remain unchanged. Avoid deeper
  indentation that would consume more width on narrow screens.

## Verification

- `git diff --check`: passed.
- Tree-sitter Swift syntax parsing: all 79 Swift files passed.
- Source checks: every Form footer receives the same inset; the suggestion
  generator differs only in string literals, not conditions or behavior.
- Independent source review: no blocking issues. Accessible completion wording
  was adjusted to contain the visible label for Voice Control.

Native build, XCTest, simulator screenshots, Dynamic Type and VoiceOver checks
were not run: this Linux environment has neither Swift nor Xcode. Syntax checks
are not a native build. Before merging, use the README's Xcode build/test steps
and inspect Settings at default and accessibility text sizes, plus the empty,
loaded, loading, completed and error states of the Today card.
