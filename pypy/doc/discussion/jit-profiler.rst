A JIT-aware profiler
====================

Goal: have a profiler which is aware of the PyPy JIT and which shows which
percentage of the time have been spent in which loops.

Long term goal: integrate the data collected by the profiler with the
jitviewer.

The idea is record an event in the PYPYLOG everytime we enter and exit a loop
or a bridge.

Expected output
----------------

[100] {jit-profile-enter
loop1      # e.g. an entry bridge
[101] jit-profile-enter}
...
[200] {jit-profile-enter
loop0      # JUMP from loop1 to loop0
[201] jit-profile-enter}
...
[500] {jit-profile-exit
loop0      # e.g. because of a failing guard
[501] jit-profile-exit}

In this example, the exiting from loop1 is implicit because we are entering
loop0.  So, we spent 200-100=100 ticks in the entry bridge, and 500-200=300
ticks in the actual loop.

What to do about "inner" bridges?
----------------------------------

"Inner bridges" are those bridges which jump back to the loop where they
originate from.  There are two possible ways of dealing with them:

  1. we ignore them: we record when we enter the loop, but not when we jump to
     a compiled inner bridge.  The exit event will be recorded only in case of
     a non-compiled guard failure or a JUMP to another loop

  2. we record the enter/exit of each inner bridge

The disadvantage of solution (2) is that there are certain loops which takes
bridges at everty single iteration.  So, in this case we would record a huge
number of events, possibly adding a lot of overhead and thus making the
profiled data useless.


Detecting the enter to/exit from a loop
----------------------------------------

Ways to enter:

    - just after the tracing/compilation

    - from the interpreter, if the loop has already been compiled

    - from another loop, via a JUMP operation

    - from a hot guard failure (which we ignore, in case we choose solution
      (1) above)

    - XXX: am I missing anything?

Ways to exit:

    - guard failure (entering blackhole)

    - guard failure (jumping to a bridge) (ignored in case of solution (1))

    - jump to another loop

    - XXX: am I missing anything?


About call_assembler: I think that at the beginning, we should just ignore
call_assembler: the time spent inside the call will be accounted to the loop
calling it.
