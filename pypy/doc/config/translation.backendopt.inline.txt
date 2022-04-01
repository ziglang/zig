Inline flowgraphs based on an heuristic, the default one considers
essentially the a weight for the flowgraph based on the number of
low-level operations in them (see
:config:`translation.backendopt.inline_threshold` ).

Some amount of inlining in order to have RPython builtin type helpers
inlined is needed for malloc removal
(:config:`translation.backendopt.mallocs`) to be effective.

This optimization is used by default.
