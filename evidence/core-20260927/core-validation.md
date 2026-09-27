# Core validation receipt — 2026-09-27

Scope: root-package MoonBit parser/window tests in the prototype. These tests do not validate the Arrow adapter or host-side CLI.

Toolchain: moon 0.1.20260904 (94521db, 2026-09-04); feature flags rr_moon_mod, rr_moon_pkg.

Commands run from the prototype root:

- `moon test --target js .` — exit 0; 6 passed, 0 failed.
- `moon test --target wasm-gc .` — exit 0; 6 passed, 0 failed.

The tests cover supported-profile parsing and retained metadata, half-open/empty windows and snapshot ownership, one-tick sampling tolerance, collapsed floating-time rejection, invalid skew/range/reserved analog/status/nonfinite values, and rejection of over-budget decoded cells.

This prototype implements a narrow OscGrid input profile (CFG 1999, ASCII DAT, one sampling segment, zero analog skew, explicit channel/row/text/cell budgets). It is not a claim of complete IEEE/COMTRADE conformance. Unsupported encodings, revisions, multiple rates, nonzero skew, and unconfirmed/missing-value cases are rejected; timestamps remain relative tick-derived time, not UTC.

SHA-256 source fingerprints (module metadata is excluded because packaging metadata is maintained separately):

| File | SHA-256 |
|---|---|
| moon.pkg | E6AF1776B165D73A74095E71FA0DB1D3C061A467D0B651F9C607B3C82D334121 |
| types.mbt | 0152CDE5DE4C5A89E7293121BFFF4696ACF45C6D49CCAF167528EA28582428CA |
| parse.mbt | CF4FE5430A516EFB6FC4446DA2D3BC9B8B0DF7FCE6BBA04E456830FF5F85D492 |
| window.mbt | D38D12F1EC8CD8B32B6DA2009A80C793644BFC7EF0BB6DD75456F29484CB658B |
| core_test.mbt | 3A5A12F5C491E815F4648E4C30B6C61D78F866421E9FDC5D59AC56D93629CDAE |
| pkg.generated.mbti | 019201C41C4676183120BD2E865981A8EE18367441E8E67BF73AA5B40AAB9454 |