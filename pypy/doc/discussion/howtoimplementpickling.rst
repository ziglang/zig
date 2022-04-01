.. XXX think more, some of this might be useful

Designing thread pickling or "the Essence of Stackless Python"
--------------------------------------------------------------

Note from 2007-07-22: This document is slightly out of date
and should be turned into a description of pickling.
Some research is necessary to get rid of explicit resume points, etc...

Thread pickling is a unique feature in Stackless Python
and should be implemented for PyPy pretty soon.

What is meant by pickling?
..........................

I'd like to define thread pickling as a restartable subset
of a running program. The re-runnable part should be based
upon Python frame chains, represented by coroutines, tasklets
or any other application level switchable subcontext.
It is surely possible to support pickling of arbitrary
interplevel state, but this seems to be not mandatory as long
as we consider Stackless as the reference implementation.
Extensions of this might be considered when the basic task
is fulfilled.

Pickling should create a re-startable coroutine-alike thing
that can run on a different machine, same Python version,
but not necessarily the same PyPy translation. This belongs
to the harder parts.

What is not meant by pickling?
..............................

Saving the whole memory state and writing a loader that
reconstructs the whole binary with its state im memory
is not what I consider a real solution. In some sense,
this can be a fall-back if we fail in every other case,
but I consider it really nasty for the C backend.

If we had a dynamic backend that supports direct creation
of the program and its state (example: a Forth backend),
I would see it as a valid solution, since it is
relocatable. It is of course a possible fall-back to write
such a backend of we fail otherwise.

There are some simple steps and some more difficult ones.
Let's start with the simple.

Basic necessities
.................

Pickling of a running thread involves a bit more than normal
object pickling, because there exist many objects which
don't have a pickling interface, and people would not care
about pickling them at all. But with thread pickling, these
objects simply exist as local variables and are needed
to restore the current runtime environment, and the user
should not have to know what goes into the pickle.

Examples are

- generators
- frames
- cells
- iterators
- tracebacks

to name just a few. Fortunately most of these objects already have
got a pickling implementation in Stackless Python, namely the
prickelpit.c file.

It should be simple and straightforward to redo these implementations.
Nevertheless there is a complication. The most natural way to support
pickling is providing a __getstate__/__setstate__ method pair.
This is ok for extension types like coroutines/tasklets which we can
control, but it should be avoided for existing types.

Consider for instance frames. We would have to add a __getstate__
and a __setstate__ method, which is an interface change. Furthermore,
we would need to support creation of frames by calling the
frame type, which is not really intended.

For other types with are already callable, things get more complicated
because we need to make sure that creating new instances does
not interfere with existing ways to call the type.

Directly adding a pickling interface to existing types is quite
likely to produce overlaps in the calling interface. This happened
for instance, when the module type became callable, and the signature
was different from what Stackless added before.

For Stackless,
I used the copyreg module, instead, and created special surrogate
objects as placeholders, which replace the type of the object
after unpickling with the right type pointer. For details, see
the prickelpit.c file in the Stackless distribution.

As a conclusion, pickling of tasklets is an addition to Stackless,
but not meant to be an extension to Python. The need to support
pickling of certain objects should not change the interface.
It is better to decouple this and to use surrogate types for
pickling which cannot collide with future additions to Python.

The real problem
................

There are currently some crucial differences between Stackless
Python (SLP for now) and the PyPy Stackless support (PyPy for now)
as far as it is grown.
When CPython does a call to a Python function, there are several
helper functions involved for adjusting parameters, unpacking
methods and some more. SLP takes a hard time to remove all these
C functions from the C stack before starting the Python interpreter
for the function. This change of behavior is done manually for
all the helper functions by figuring out, which variables are
still needed after the call. It turns out that in most cases,
it is possible to let all the helper functions finish their
work and return form the function call before the interpreter
is started at all.

This is the major difference which needs to be tackled for PyPy.
Whenever we run a Python function, quite a number of functions
incarnate on the C stack, and they get *not* finished before
running the new frame. In case of a coroutine switch, we just
save the whole chain of activation records - c function
entrypoints with the saved block variables. This is ok for
coroutine switching, but in the sense of SLP, it is rather
incomplete and not stackless at all. The stack still exists,
we can unwind and rebuild it, but it is a problem.

Why a problem?
..............

In an ideal world, thread pickling would just be building
chains of pickled frames and nothing else. For every different
extra activation record like mentioned above, we have the
problem of how to save this information. We need a representation
which is not machine or compiler dependent. Right now, PyPy
is quite unstable in terms of which blocks it will produce,
what gets inlined, etc. The best solution possible is to try
to get completely rid of these extra structures.

Unfortunately this is not even possible with SLP, because
there are different flavors of state which make it hard
to go without extra information.

SLP switching strategies
........................

SLP has undergone several rewrites. The first implementation was aiming
at complete collaboration. A new frame's execution was deferred until
all the preparational C function calls had left the C stack. There
was no extra state to be saved.

Well, this is only partially true - there are a couple of situations
where a recursive call could not be avoided, since the necessary support
would require heavy rewriting of the implementation.

Examples are

- map is a stateful implementation of iterating over a sequence
  of operations. It can be made non-recursive if the map operation
  creates its own frame to keep state.

- __init__ looks trivial, but the semantics is that the return value
  of __init__ is supposed to be None, and CPy has a special check for this
  after the call. This might simply be ignored, but it is a simple example
  for a case that cannot be handled automatically.

- things like operator.__add__ can theoretically generate a wild pattern
  of recursive calls while CPy tries to figure out if it is a numeric
  add or a sequence add, and other callbacks may occur when methods
  like __coerce__ get involved. This will never be solved for SLP, but
  might get a solution by the strategy outlined below.

The second implementation took a radically different approach. Context
switches were done by hijacking parts of the C stack, storing them
away and replacing them by the stack fragment that the target needs.
This is very powerful and allows to switch even in the context of
foreign code. With a little risk, I was even able to add concurrency
to foreign Fortran code.

The above concept is called Hard (switching), the collaborative Soft (switching).
Note that an improved version of Hard is still the building block
for greenlets, which makes them not really green - I'd name it yellow.

The latest SLP rewrites combine both ideas, trying to use Soft whenever
possible, but using Hard when nested interpreters are in the way.

Notabene, it was never tried to pickle tasklets when Hard
was involved. In SLP, pickling works with Soft. To gather more
pickleable situations, you need to invent new frame types
or write replacement Python code and switch it using Soft.

Analogies between SLP and PyPy
..............................

Right now, PyPy saves C state of functions in tiny activation records:
the alive variables of a block, together with the entry point of
the function that was left.
This is an improvement over storing raw stack slices, but the pattern
is similar: The C stack state gets restored when we switch.

In this sense, it was the astonishing resume when Richard and I discussed
this last week: PyPy essentially does a variant of Hard switching! At least it
does a compromise that does not really help with pickling.

On the other hand, this approach is half the way. It turns out to
be an improvement over SLP not to have to avoid recursions in the
first place. Instead, it seems to be even more elegant and efficient
to get rid of unnecessary state right in the context of a switch
and no earlier!

Ways to handle the problem in a minimalistic way
................................................

Comparing the different approaches of SLP and PyPy, it appears to be
not necessary to change the interpreter in the first place. PyPy does
not need to change its calling behavior in order to be cooperative.
The key point is to find out which activation records need to
be stored at all. This should be possible to identify as a part
of the stackless transform.

Consider the simple most common case of calling a normal Python function.
There are several calls to functions involved, which do preparational
steps. Without trying to be exact (this is part of the work to be done),
involved steps are

- decode the arguments of the function

- prepare a new frame

- store the arguments in the frame

- execute the frame

- return the result

Now assume that we do not execute the frame, but do a context switch instead,
then right now a sequence of activation records is stored on the heap.
If we want to re-activate this chain of activation records, what do
we really need to restore before we can do the function call?

- the argument decoding is done, already, and the fact that we could have done
  the function call shows, that no exception occurred. We can ignore the rest
  of this activation record and do the housekeeping.

- the frame is prepared, and arguments are stored in it. The operation
  succeeded, and we have the frame. We can ignore exception handling
  and just do housekeeping by getting rid of references.

- for executing the frame, we need a special function that executes frames. It
  is possible that we need different flavors due to contexts. SLP does this
  by using different registered functions which operate on a frame, depending
  on the frame's state (first entry, reentry after call, returning, yielding etc)

- after executing the frame, exceptions need to be handled in the usual way,
  and we should return to the issuer of the call.

Some deeper analysis is needed to get these things correct.
But it should have become quite clear, that after all the preparational
steps have been done, there is no other state necessary than what we
have in the Python frames: bound arguments, instruction pointer, that's it.

My proposal is now to do such an analysis by hand, identify the different
cases to be handled, and then trying to find an algorithm that automatically
identifies the blocks in the whole program, where the restoring of the
C stack can be avoided, and we can jump back to the previous caller, directly.

A rough sketch of the necessary analysis:

for every block in an RPython function that can reach unwind:
Analyze control flow. It should be immediately leading to
the return block with only one output variable. All other alive variables
should have ended their liveness in this block.

I think this will not work in the first place. For the bound frame
arguments for instance, I think we need some notation that these are
held by the frame, and we can drop their liveness before doing the call,
hence we don't need to save these variables in the activation record,
and hence the whole activation record can be removed.

As a conclusion of this incomplete first analysis, it seems to be necessary
to identify useless activation records in order to support pickling.
The remaining, irreducible activation records should then be those
which hold a reference to a Python frame.
Such a chain is pickleable if its root points back to the context switching code
of the interp-level implementation of coroutines.

As an observation, this transform not only enables pickling, but
also is an optimization, if we can avoid saving many activation records.

Another possible observation which I hope to be able to prove is this:
The remaining irreducible activation records which don't just hold
a Python frame are those which should be considered special.
They should be turned into something like special frames, and they would
be the key to make PyPy completely stackless, a goal which is practically
impossible for SLP! These activation records would need to become
part of the official interface and need to get naming support for
their necessary functions.

I wish to stop this paper here. I believe everything else
needs to be tried in an implementation, and this is so far
all I can do just with imagination.

best - chris

Just an addition after some more thinking
.........................................

Actually it struck me after checking this in, that the problem of
determining which blocks need to save state and which not it not
really a Stackless problem. It is a system-immanent problem
of a missing optimization that we still did not try to solve.

Speaking in terms of GC transform, and especially the refcounting,
it is probably easy to understand what I mean. Our current refcounting
implementation is naive, in the sense that we do not try to do the
optimizations which every extension writer does by hand:
We do not try to save references.

This is also why I'm always arguing that refcounting can be and
effectively *is* efficient, because CPython does it very well.

Our refcounting is not aware of variable lifeness, it does not
track references which are known to be held by other objects.
Optimizing that would do two things: The refcounting would become
very efficient, since we would save some 80 % of it.
The second part, which is relevant to the pickling problem is this:
By doing a proper analysis, we already would have lost references to
all the variables which we don't need to save any longer, because
we know that they are held in, for instance, frames.

I hope you understand that: If we improve the life-time analysis
of variables, the sketched problem of above about which blocks
need to save state and which don't, should become trivial and should
just vanish. Doing this correctly will solve the pickling problem quasi
automatically, leading to a more efficient implementation at the same time.

I hope I told the truth and will try to prove it.

ciao - chris
