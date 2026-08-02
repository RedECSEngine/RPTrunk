# RPTrunk — project rules

## Comments: do not write them

**This codebase is documented by hand, by Kai.** Every comment in it was written
deliberately. Do **not** add your own — not inline comments, not rationale
blocks, not doc-comment headers, not `MARK:` banners, not "why" notes, not TODOs.
Zero.

This holds even when the code is subtle, when the reasoning is non-obvious, and
when the file you are editing is already dense with comments. **Those are Kai's
comments** — leave them exactly as they are and do not add siblings to match the
style. Do not reformat or reword them either.

The **only** exception is when Kai explicitly asks for a comment in a specific
place.

When something genuinely needs explaining, put it in the pull request body, the
commit message, or say it in chat — never in the source.

Rationalizations that do not apply:

- "the surrounding file is full of doc comments, so matching the style is right"
- "this one is genuinely subtle / a units change / a footgun"
- "tests are different" — they are not; put the explanation in the
  `XCTAssert` message, where it shows up on failure
- "I'll write it now and tidy it up later" — hold at zero from the first draft
