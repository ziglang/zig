=========================
PyPy's assembler backends
=========================

Draft notes about the organization of assembler backends in the PyPy JIT, in 2016
=================================================================================


input: linear sequence of instructions, called a "trace".

A trace is a sequence of instructions in SSA form.  Most instructions
correspond to one or a few CPU-level instructions.  There are a few
meta-instructions like `label` and debugging stuff.  All branching is
done with guards, which are instructions that check that a condition is
true and exit the trace if not.  A failing guard can have a new trace
added to it later, called a "bridge".  A patched guard becomes a direct
`Jcond` instruction going to the bridge, with no indirection, no
register spilling, etc.

A trace ends with either a `return` or a `jump to label`.  The target
label is either inside the same trace, or in some older one.  For
historical reasons we call a "loop" a trace that is not a bridge.  The
machine code that we generate is organized as a forest of trees; the
trunk of the tree is a "loop", and the branches are all bridges
(branching off the trunk or off another branch).

* every trunk or branch that ends in a `jump to label` can target a
  label from a different tree, too.

* the whole process of assembling a loop or a branch is basically
  single-threaded, so no synchronization issue there (including to patch
  older generated instructions).

* the generated assembler has got a "frame" in %rbp, which is actually
  not on the stack at all, but is a GC object (called a "jitframe").
  Spilling goes there.

* the guards are `Jcond` to a very small piece of generated code, which
  is basically pushing a couple of constants on the stack and then
  jumping to the general guard-recovery code.  That code will save the
  registers into the jitframe and then exit the whole generated
  function.  The caller of that generated function checks how it
  finished: if it finished by hitting a guard, then the caller is
  responsible for calling the "blackhole interpreter".  This is the part
  of the front-end that recovers from failing guards and finishes
  running the frame (including, possibly, by jumping again into
  generated assembler).


Details about the JITting process:

* front-end and optimization pass

* rewrite (includes gc related transformation as well as simplifactions)

* assembler generation


Front-end and optimization pass
-------------------------------

Not discussed here in detail.  This produces loops and bridges using an
instruction set that is "high-level" in some sense: it contains
intructions like "new"/"new_array", and
"setfield"/"setarrayitem"/"setinteriorfield" which describe the action
of storing a value in a precise field of the structure or array.  For
example, the "setfield" action might require implicitly a GC write
barrier.  This is the high-level trace that we send to the following
step.


Rewrite
-------

A mostly but not completely CPU-independent phase: lowers some
instructions.  For example, the variants of "new" are lowered to
"malloc" and a few "gc_store": it bumps the pointer of the GC and then
sets a few fields explicitly in the newly allocated structure.  The
"setfield" is replaced with a "cond_gc_wb_call" (conditional call to the
write barrier) if needed, followed by a "gc_store".

The "gc_store" instruction can be encoded in a single MOV assembler
instruction, but is not as flexible as a MOV.  The address is always
specified as "some GC pointer + an offset".  We don't have the notion of
interior pointer for GC objects.

A different instruction, "gc_store_indexed", offers additional operands,
which can be mapped to a single MOV instruction using forms like
`[rax+8*rcx+24]`.

Some other complex instructions pass through to the backend, which must
deal with them: for example, "card marking" in the GC.  (Writing an
object pointer inside an array would require walking the whole array
later to find "young" references. Instead of that, we flip a bit for
every range of 128 entries.  This is a common GC optimization.)  Setting
the card bit of a GC object requires a sequence of assembler
instructions that depends too much on the target CPU to be expressed
explicitly here (moreover, it contains a few branches, which are hard to
express at this level).


Assembly
--------

No fancy code generation technique, but greedy forward pass that tries
to avoid some pitfalls


Handling instructions
~~~~~~~~~~~~~~~~~~~~~

* One by one (forward direction).   Each instruction asks the register
  allocator to ensure that some arguments are in registers (not in the
  jitframe); asks for a register to put its result into; and asks for
  additional scratch registers that will be freed at  the end of the
  instruction.  There is a special case for boolean variables: they are
  stored in the condition code flags instead of being materialized as a
  0/1 value.  (They are materialized later, except in the common case
  where they are only used by the next `guard_false` or `guard_true` and
  then forgotten.)

* Instruction arguments are loaded into a register on demand.  This
  makes the backend quite easy to write, but leads do some bad
  decisions.


Linear scan register allocation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Although it's always a linear trace that we consider, we don't use
advanced techniques for register allocation: we do forward, on-demand
allocation as the backend produces the assembler.  When it asks for a
register to put some value into, we give it any free register, without
consideration for what will be done with it later.  We compute the
longevity of all variables, but only use it when choosing which register
to spill (we spill the variable with the longest longevity).

This works to some extend because it is well integrated with the earlier
optimization pass. Loops are unrolled once by the optimization pass to
allow more powerful optimizations---the optimization pass itself is the
place that benefits the most, but it also has benefits here in the
assembly pass.  These are:

* The first peeling initializes the register binding on the first use.

* This leads to an already allocated register of the trace loop.

* As well as allocated registers when exiting bridges

[Try to better allocate registers to match the ABI (minor to non benefit
in the current state)]


More complex mappings
~~~~~~~~~~~~~~~~~~~~~

Some instructions generate more complex code.  These are either or both of:

* complex instructions generating some local control flow, like
  "cond_gc_wb_call" (for write barriers), "call_assembler" (a call
  followed by a few checks).

* instructions that invoke custom assembler helpers, like the slow-path
  of write barriers or the slow-path of allocations.  These slow-paths
  are typically generated too, so that we are not constrained by the
  usual calling conventions.


GC pointers
~~~~~~~~~~~

Around most CALL instructions, we need to record a description of where
the GC pointers are (registers and stack frame).  This is needed in case
the CALL invokes a garbage collection.  The GC pointers can move; the
pointers in the registers and stack frame are updated by the GC.  That's
a reason for why we don't have explicit interior pointers.

GC pointers can appear as constants in the trace.  We are busy changing
that to use a constant table and `MOV REG, (%RIP+offset)`.  The
"constant" in the table is actually updated by the GC if the object
move.


Vectorization
~~~~~~~~~~~~~

Optimization developed to use SIMD instructions for trace loops. Primary
idea was to use it as an optimization of micro numpy. It has several
passes on the already optimized trace.

Shortly explained: It builds dependencies for an unrolled trace loop,
gathering pairs/packs of operations that could be executed in parallel
and finally schedules the operations.

What did it add to the code base:

* Dependencies can be constructed

* Code motion of guards to relax dependencies

* Scheduler to reorder trace

* Array bound check removal (especially for unrolled traces)

What can it do:

* Transform vector loops (element wise operations)

* Accumulation (`reduce([...],operator,0)`). Requires Operation to be
  associative and commutative

* SSE 4.1 as "vector backend"


We do not
~~~~~~~~~

* Keep tracing data around to reoptimize the trace tree. (Once a trace
  is compiled, minimal data is kept.)  This is one reason (there are
  others in the front-end) for the following result: JIT-compiling a
  small loop with two common paths ends up as one "loop" and one bridge
  assembled, and the bridge-following path is slightly less efficient.
  This is notably because this bridge is assembled with two constraints:
  the input registers are fixed (from the guard), and the output
  registers are fixed (from the jump target); usually these two sets of
  fixed registers are different, and copying around is needed.

* We don't join trace tails: we only assemble *trees*.

* We don't do any reordering (neither of trace instructions nor of
  individual assembler instructions)

* We don't do any cross-instruction optimization that makes sense only
  for the backend and can't easily be expressed at a higher level.  I'm
  sure there are tons of examples of that, but e.g. loading a large
  constant in a register that will survive for several instructions;
  moving out of loops *parts* of some instruction like the address
  calculation; etc. etc.

* Other optimization opportunities I can think about: look at the
  function prologue/epilogue; look at the overhead (small but not zero)
  at the start of a bridge.  Also check if the way guards are
  implemented makes sense.  Also, we generate large-ish sequences of
  assembler instructions with tons of `Jcond` that are almost never
  followed; any optimization opportunity there?  (They all go forward,
  if it changes anything.)  In theory we could also replace some of
  these with a signal handler on segfault (e.g. `guard_nonnull_class`).


a GCC or LLVM backend?
~~~~~~~~~~~~~~~~~~~~~~

At least for comparison we'd like a JIT backend that emits its code
using GCC or LLVM (irrespective of the time it would take).  But it's
hard to map reasonably well the guards to the C language or to LLVM IR.
The problems are: (1) we have many guards, we would like to avoid having
many paths that each do a full
saving-all-local-variables-that-are-still-alive; (2) it's hard to patch
a guard when a bridge is compiled from it; (3) instructions like a CALL
need to expose the local variables that are GC pointers; CALL_MAY_FORCE
need to expose *all* local variables for optional off-line
reconstruction of the interpreter state.

