Inline flowgraphs only for call-sites for which there was a minimal
number of calls during an instrumented run of the program. Callee
flowgraphs are considered candidates based on a weight heuristic like
for basic inlining. (see :config:`translation.backendopt.inline`,
:config:`translation.backendopt.profile_based_inline_threshold` ).

The option takes as value a string which is the arguments to pass to
the program for the instrumented run.

This optimization is not used by default.