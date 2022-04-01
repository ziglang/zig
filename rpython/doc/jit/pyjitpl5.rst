PyJitPl5
========

This document describes the fifth generation of the RPython JIT generator.


Implementation of the JIT
-------------------------

The JIT's :doc:`theory <overview>` is great in principle, but the actual code is a different
story. This section tries to give a high level overview of how RPython's JIT is
implemented.  It's helpful to have an understanding of how the :doc:`RPython translation
toolchain <../translation>` works before digging into the sources.

Almost all JIT specific code is found in rpython/jit subdirectories.  Translation
time code is in the codewriter directory.  The metainterp directory holds
platform independent code including the the tracer and the optimizer.  Code in
the backend directory is responsible for generating machine code.


JIT hints
~~~~~~~~~

To add a JIT to an interpreter, RPython only requires two hints to be added to
the target interpreter.  These are jit_merge_point and can_enter_jit.
jit_merge_point is supposed to go at the start of opcode dispatch.  It allows
the JIT to bail back to the interpreter in case running machine code is no
longer suitable.  can_enter_jit goes at the end of a application level loop.  In
the Python interpreter, this is the JUMP_ABSOLUTE bytecode.  The Python
interpreter defines its hints in pypy/module/pypyjit/interp_jit.py in a few
overridden methods of the default interpreter loop.

An interpreter wishing to use the RPython JIT generator must define a list of *green*
variables and a list of *red* variables.  The *green* variables are loop
constants.  They are used to identify the current loop.  Red variables are for
everything else used in the execution loop.  For example, the Python interpreter
passes the code object and the instruction pointer as greens and the frame
object and execution context as reds.  These objects are passed to the JIT at
the location of the JIT hints.


JIT Generation
~~~~~~~~~~~~~~

After the RTyping phase of translation, where high level Python operations are
turned into low-level ones for the backend, the translation driver calls
apply_jit() in metainterp/warmspot.py to add a JIT compiler to the currently
translating interpreter.  apply_jit() decides what assembler backend to use then
delegates the rest of the work to the WarmRunnerDesc class.  WarmRunnerDesc
finds the two JIT hints in the function graphs.  It rewrites the graph
containing the jit_merge_point hint, called the portal graph, to be able to
handle special JIT exceptions, which indicate special conditions to the
interpreter upon exiting from the JIT.  The location of the can_enter_jit hint
is replaced with a call to a function, maybe_compile_and_run in warmstate.py,
that checks if current loop is "hot" and should be compiled.

Next, starting with the portal graph, codewriter/\*.py converts the graphs of the
interpreter into JIT bytecode.  Since this bytecode is stored in the final
binary, it's designed to be concise rather than fast.  The bytecode codewriter
doesn't "see" (what it sees is defined by the JIT's policy) every part of the
interpreter.  In these cases, it simply inserts an opaque call.

Finally, translation finishes, including the bytecode of the interpreter in the
final binary, and interpreter is ready to use the runtime component of the JIT.


Tracing
~~~~~~~

Application code running on the JIT-enabled interpreter starts normally; it is
interpreted on top of the usual evaluation loop.  When an application loop is
closed (where the can_enter_jit hint was), the interpreter calls the
maybe_compile_and_run() method of WarmEnterState.  This method increments a
counter associated with the current green variables.  When this counter reaches
a certain level, usually indicating the application loop has been run many
times, the JIT enters tracing mode.

*Tracing* is where JIT interprets the bytecode, generated at translation time,
of the interpreter interpreting the application level code.  This allows it to
see the exact operations that make up the application level loop.  Tracing is
performed by MetaInterp and MIFrame classes in metainterp/pyjitpl.py.
maybe_compile_and_run() creates a MetaInterp and calls its
compile_and_run_once() method.  This initializes the MIFrame for the input
arguments of the loop, the red and green variables passed from the
jit_merge_point hint, and sets it to start interpreting the bytecode of the
portal graph.

Before starting the interpretation, the loop input arguments are wrapped in a
*box*.  Boxes (defined in metainterp/history.py) wrap the value and type of a
value in the program the JIT is interpreting.  There are two main varieties of
boxes: constant boxes and normal boxes.  Constant boxes are used for values
assumed to be known during tracing.  These are not necessarily compile time
constants.  All values which are "promoted", assumed to be constant by the JIT
for optimization purposes, are also stored in constant boxes.  Normal boxes
contain values that may change during the running of a loop.  There are three
kinds of normal boxes: BoxInt, BoxPtr, and BoxFloat, and four kinds of constant
boxes: ConstInt, ConstPtr, ConstFloat, and ConstAddr.  (ConstAddr is only used
to get around a limitation in the translation toolchain.)

The meta-interpreter starts interpreting the JIT bytecode.  Each operation is
executed and then recorded in a list of operations, called the trace.
Operations can have a list of boxes they operate on, arguments.  Some operations
(like GETFIELD and GETARRAYITEM) also have special objects that describe how
their arguments are laid out in memory.  All possible operations generated by
tracing are listed in metainterp/resoperation.py.  When a (interpreter-level)
call to a function the JIT has bytecode for occurs during tracing, another
MIFrame is added to the stack and the tracing continues with the same history.
This flattens the list of operations over calls.  Most importantly, it unrolls
the opcode dispatch loop.  Interpretation continues until the can_enter_jit hint
is seen.  At this point, a whole iteration of the application level loop has
been seen and recorded.

Because only one iteration has been recorded the JIT only knows about one
codepath in the loop.  For example, if there's a if statement construct like
this::

   if x:
       do_something_exciting()
   else:
       do_something_else()

and ``x`` is true when the JIT does tracing, only the codepath
``do_something_exciting`` will be added to the trace.  In future runs, to ensure
that this path is still valid, a special operation called a *guard operation* is
added to the trace.  A guard is a small test that checks if assumptions the JIT
makes during tracing are still true.  In the example above, a GUARD_TRUE guard
will be generated for ``x`` before running ``do_something_exciting``.

Once the meta-interpreter has verified that it has traced a loop, it decides how
to compile what it has.  There is an optional optimization phase between these
actions which is covered future down this page.  The backend converts the trace
operations into assembly for the particular machine.  It then hands the compiled
loop back to the frontend.  The next time the loop is seen in application code,
the optimized assembly can be run instead of the normal interpreter.


Optimizations
~~~~~~~~~~~~~

The JIT employs several techniques, old and new, to make machine code run
faster.

Virtuals and Virtualizables
"""""""""""""""""""""""""""

A *virtual* value is an array, struct, or RPython level instance that is created
during the loop and does not escape from it via calls or longevity past the
loop.  Since it is only used by the JIT, it can be "optimized out"; the value
doesn't have to be allocated at all and its fields can be stored as first class
values instead of deferencing them in memory.  Virtuals allow temporary objects
in the interpreter to be unwrapped.  For example, a W_IntObject in the PyPy interpreter can
be unwrapped to just be its integer value as long as the object is known not to
escape the machine code.

A *virtualizable* is similar to a virtual in that its structure is optimized out
in the machine code.  Virtualizables, however, can escape from JIT controlled
code.

Other optimizations
"""""""""""""""""""

Most of the JIT's optimizer is contained in the subdirectory
``metainterp/optimizeopt/``.  Refer to it for more details.


More resources
--------------

More documentation about the current JIT is available as a first published
article:

* `Tracing the Meta-Level: PyPy's Tracing JIT Compiler`__

.. __: https://bitbucket.org/pypy/extradoc/src/tip/talk/icooolps2009/bolz-tracing-jit-final.pdf

Chapters 5 and 6 of `Antonio Cuni's PhD thesis`__ contain an overview of how
Tracing JITs work in general and more informations about the concrete case of
PyPy's JIT.

.. __: http://antocuni.eu/download/antocuni-phd-thesis.pdf

The `blog posts with the JIT tag`__ might also contain additional information.

.. __: http://morepypy.blogspot.com/search/label/jit
