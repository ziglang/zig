========
JIT help
========

.. note this is from ``pypy --jit help``

Advanced JIT options
====================

``<pypy> --jit`` [*options*] where *options* is a comma-separated list of
``OPTION=VALUE``:

 decay=N
    amount to regularly decay counters by (0=none, 1000=max) (default 40)

 disable_unrolling=N
    after how many operations we should not unroll (default 200)

 enable_opts=N
    INTERNAL USE ONLY (MAY NOT WORK OR LEAD TO CRASHES): optimizations to
    enable, or all =
    intbounds:rewrite:virtualize:string:pure:earlyforce:heap:unroll (default
    all)

 function_threshold=N
    number of times a function must run for it to become traced from start
    (default 1619)

 inlining=N
    inline python functions or not (1/0) (default 1)

 loop_longevity=N
    a parameter controlling how long loops will be kept before being freed,
    an estimate (default 1000)

 max_retrace_guards=N
    number of extra guards a retrace can cause (default 15)

 max_unroll_loops=N
    number of extra unrollings a loop can cause (default 0)

 max_unroll_recursion=N
    how many levels deep to unroll a recursive function (default 7)

 retrace_limit=N
    how many times we can try retracing before giving up (default 0)

 threshold=N
    number of times a loop has to run for it to become hot (default 1039)

 trace_eagerness=N
    number of times a guard has to fail before we start compiling a bridge
    (default 200)

 trace_limit=N
    number of recorded operations before we abort tracing with ABORT_TOO_LONG
    (default 6000)

 vec=N
    turn on the vectorization optimization (vecopt). Supports x86 (SSE 4.1),
    powerpc (SVX), s390x SIMD (default 0)

 vec_all=N
    try to vectorize trace loops that occur outside of the numpypy library
    (default 0)

 vec_cost=N
    threshold for which traces to bail. Unpacking increases the counter,
    vector operation decrease the cost (default 0)

 off
    turn off the JIT
 help
    print this page

The :ref:`pypyjit<jit-hooks>` module can be used to control the JIT from inside
pypy

