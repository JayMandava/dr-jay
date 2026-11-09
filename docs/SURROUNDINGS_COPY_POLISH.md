# Surroundings copy and justified Settings subtext

Based on merged main `198238b`.

- Keep the Settings disclosure to the action, recipient and data shared.
  The bundled Privacy Policy retains the storage, precision and scoring details.
- Keep the card footer to optional participation, the separate daily bonus cap
  and personal fluid/dietary guidance. Shorten all five suggestion descriptions.
- Use a short completion button label, with an accessible name that includes
  its visible wording and identifies the suggestion.
- Justify all nine Form section footers in Settings and its Theme screen,
  aligning wrapped lines to both edges. The final line remains naturally aligned.
  The originally added leading indentation has been removed.
- SwiftUI Text lacks justified alignment, so a small native UILabel wrapper
  supplies it. Unlimited lines and width-aware height measurement avoid truncation.
  A footnote-relative ScaledMetric preserves Dynamic Type, semantic secondary
  color adapts to appearance, Bold Text is respected, and the label exposes
  its text to VoiceOver.
- Justification is the requested visual treatment. Narrow widths and large text
  may produce larger spaces between words; inspect these on device before merge.

## Verification

- `git diff --check`: passed.
- Tree-sitter Swift syntax parsing: all 79 Swift files passed.
- Source checks: every Form footer uses the same justified component; the suggestion
  generator differs only in string literals, not conditions or behavior.
- Independent source review found no blocking issues in the copy or wrapper.
  Device verification of RTL final-line alignment remains outstanding. Accessible
  completion wording contains the visible label for Voice Control.

Native build, XCTest, simulator screenshots, Dynamic Type and VoiceOver checks
were not run: this Linux environment has neither Swift nor Xcode. Syntax checks
are not a native build. Before merging, use the README's Xcode build/test steps
and inspect Settings at default and accessibility text sizes, plus the empty,
loaded, loading, completed and error states of the Today card.
