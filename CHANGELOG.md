## 0.8.0 (2023-07-16)

- Support for base >= 4.15 / GHC 9.
- Dropped support for GHC versions that have no corresponding HLS version.

## 0.7.0 (2019-09-12)

- New `%Q` and `%q` format specifiers accept strict and lazy Text as input
  respectively. Otherwise they function identically to the `%s` specifier.
- th-printf can now produce lazy Text as well as String, and the improved
  internal representation of format strings should slightly increase performance.
  - Directly producing Text should now be significantly faster than using the
    string formatter and `pack`ing the result, especially with Text format arguments.
- Dropped support for GHC < 8.

## 0.6.0 (2018-08-18)

Backported new backpack-based code to pre GHC-8.4 versions.

- Rename of public modules
- Parser rewrite
- th-printf now prints a warning when given an erroneous format string
- Several printf behaviors have been updated to comply with spec:
  - `x`, `u`, etc. specifiers now only apply to positive integers
  - Length specifiers are allowed
- Generated testsuite covers more cases
