# Bundled typography

MAYHEM ships its two UI fonts with the application so typography remains
stable on Android and iOS and never depends on a runtime network request.

The files were copied from the official `google/fonts` repository at commit
`966486d0728ceec5dc3b79cbad3073371bac51c0`:

- `manrope/Manrope-VariableFont_wght.ttf`
  - upstream: `ofl/manrope/Manrope[wght].ttf`
  - SHA-256: `d0639be45d0af36e798172419d7bd173c4bd4f29e2b76cbb69db1d11bf8b0a40`
  - used for body copy, controls, labels, and navigation titles;
- `unbounded/Unbounded-VariableFont_wght.ttf`
  - upstream: `ofl/unbounded/Unbounded[wght].ttf`
  - SHA-256: `323b511be380c8d474ef030686b71aedde501f8d9cd46da558b7c40454372c3f`
  - used for display headings, rank names, and status numbers.

Both families are distributed under the SIL Open Font License 1.1. The exact
upstream license text is retained beside each font as `OFL.txt`.
