Try to inline flowgraphs based on whether doing so would enable malloc
removal (:config:`translation.backendopt.mallocs`.) by eliminating
calls that result in escaping. This is an experimental optimization,
also right now some eager inlining is necessary for helpers doing
malloc itself to be inlined first for this to be effective.
This option enable also an extra subsequent malloc removal phase.

Callee flowgraphs are considered candidates based on a weight heuristic like
for basic inlining. (see :config:`translation.backendopt.inline`,
:config:`translation.backendopt.clever_malloc_removal_threshold` ).
