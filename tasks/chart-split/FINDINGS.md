# Chart findings

No behavior bugs were discovered. No behavior fixes were made.

Opaque public unions keep their constructor/payload and documentation shapes.
Every original implementation is retained in one internal module, and the public
facade only adapts and forwards values. Existing report-only check warnings remain
unchanged, as required by the pure-refactor scope.
