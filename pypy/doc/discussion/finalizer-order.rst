Ordering finalizers in the MiniMark GC
======================================


RPython interface
-----------------

In RPython programs like PyPy, we need a fine-grained method of
controlling the RPython- as well as the app-level ``__del__()``.  To
make it possible, the RPython interface is now the following one (from
May 2016):

* RPython objects can have ``__del__()``.  These are called
  immediately by the GC when the last reference to the object goes
  away, like in CPython.  However, the long-term goal is that all
  ``__del__()`` methods should only contain simple enough code.  If
  they do, we call them "destructors".  They can't use operations that
  would resurrect the object, for example.  Use the decorator
  ``@rgc.must_be_light_finalizer`` to ensure they are destructors.

* RPython-level ``__del__()`` that are not passing the destructor test
  are supported for backward compatibility, but deprecated.  The rest
  of this document assumes that ``__del__()`` are all destructors.

* For any more advanced usage --- in particular for any app-level
  object with a __del__ --- we don't use the RPython-level
  ``__del__()`` method.  Instead we use
  ``rgc.FinalizerController.register_finalizer()``.  This allows us to
  attach a finalizer method to the object, giving more control over
  the ordering than just an RPython ``__del__()``.

We try to consistently call ``__del__()`` a destructor, to distinguish
it from a finalizer.  A finalizer runs earlier, and in topological
order; care must be taken that the object might still be reachable at
this point if we're clever enough.  A destructor on the other hand runs
last; nothing can be done with the object any more, and the GC frees it
immediately.


Destructors
-----------

A destructor is an RPython ``__del__()`` method that is called directly
by the GC when it is about to free the memory.  Intended for objects
that just need to free an extra block of raw memory.

There are restrictions on the kind of code you can put in ``__del__()``,
including all other functions called by it.  These restrictions are
checked.  In particular you cannot access fields containing GC objects.
Right now you can't call any external C function either.

Destructors are called precisely when the GC frees the memory of the
object.  As long as the object exists (even in some finalizer queue or
anywhere), its destructor is not called.


Register_finalizer
------------------

The interface for full finalizers is made with PyPy in mind, but should
be generally useful.

The idea is that you subclass the ``rgc.FinalizerQueue`` class:

* You must give a class-level attribute ``base_class``, which is the
  base class of all instances with a finalizer.  (If you need
  finalizers on several unrelated classes, you need several unrelated
  ``FinalizerQueue`` subclasses.)

* You override the ``finalizer_trigger()`` method; see below.

Then you create one global (or space-specific) instance of this
subclass; call it ``fin``.  At runtime, you call
``fin.register_finalizer(obj)`` for every instance ``obj`` that needs
a finalizer.  Each ``obj`` must be an instance of ``fin.base_class``,
but not every such instance needs to have a finalizer registered;
typically we try to register a finalizer on as few objects as possible
(e.g. only if it is an object which has an app-level ``__del__()``
method).

After a major collection, the GC finds all objects ``obj`` on which a
finalizer was registered and which are unreachable, and mark them as
reachable again, as well as all objects they depend on.  It then picks
a topological ordering (breaking cycles randomly, if any) and enqueues
the objects and their registered finalizer functions in that order, in
a queue specific to the prebuilt ``fin`` instance.  Finally, when the
major collection is done, it calls ``fin.finalizer_trigger()``.

This method ``finalizer_trigger()`` can either do some work directly,
or delay it to be done later (e.g. between two bytecodes).  If it does
work directly, note that it cannot (directly or indirectly) cause the
GIL to be released.

To find the queued items, call ``fin.next_dead()`` repeatedly.  It
returns the next queued item, or ``None`` when the queue is empty.

In theory, it would kind of work if you cumulate several different
``FinalizerQueue`` instances for objects of the same class, and
(always in theory) the same ``obj`` could be registered several times
in the same queue, or in several queues.  This is not tested though.
For now the untranslated emulation does not support registering the
same object several times.

Note that the Boehm garbage collector, used in ``rpython -O0``,
completely ignores ``register_finalizer()``.


Ordering of finalizers
----------------------

After a collection, the MiniMark GC should call the finalizers on
*some* of the objects that have one and that have become unreachable.
Basically, if there is a reference chain from an object a to an object b
then it should not call the finalizer for b immediately, but just keep b
alive and try again to call its finalizer after the next collection.

(Note that this creates rare but annoying issues as soon as the program
creates chains of objects with finalizers more quickly than the rate at
which major collections go (which is very slow).  In August 2013 we tried
instead to call all finalizers of all objects found unreachable at a major
collection.  That branch, ``gc-del``, was never merged.  It is still
unclear what the real consequences would be on programs in the wild.)

The basic idea fails in the presence of cycles.  It's not a good idea to
keep the objects alive forever or to never call any of the finalizers.
The model we came up with is that in this case, we could just call the
finalizer of one of the objects in the cycle -- but only, of course, if
there are no other objects outside the cycle that has a finalizer and a
reference to the cycle.

More precisely, given the graph of references between objects::

    for each strongly connected component C of the graph:
        if C has at least one object with a finalizer:
            if there is no object outside C which has a finalizer and
            indirectly references the objects in C:
                mark one of the objects of C that has a finalizer
                copy C and all objects it references to the new space

    for each marked object:
        detach the finalizer (so that it's not called more than once)
        call the finalizer


Algorithm
---------

During deal_with_objects_with_finalizers(), each object x can be in 4
possible states::

    state[x] == 0:  unreachable
    state[x] == 1:  (temporary state, see below)
    state[x] == 2:  reachable from any finalizer
    state[x] == 3:  alive

Initially, objects are in state 0 or 3 depending on whether they have
been copied or not by the regular sweep done just before.  The invariant
is that if there is a reference from x to y, then state[y] >= state[x].

The state 2 is used for objects that are reachable from a finalizer but
that may be in the same strongly connected component than the finalizer.
The state of these objects goes to 3 when we prove that they can be
reached from a finalizer which is definitely not in the same strongly
connected component.  Finalizers on objects with state 3 must not be
called.

Let closure(x) be the list of objects reachable from x, including x
itself.  Pseudo-code (high-level) to get the list of marked objects::

    marked = []
    for x in objects_with_finalizers:
        if state[x] != 0:
            continue
        marked.append(x)
        for y in closure(x):
            if state[y] == 0:
                state[y] = 2
            elif state[y] == 2:
                state[y] = 3
    for x in marked:
        assert state[x] >= 2
        if state[x] != 2:
            marked.remove(x)

This does the right thing independently on the order in which the
objects_with_finalizers are enumerated.  First assume that [x1, .., xn]
are all in the same unreachable strongly connected component; no object
with finalizer references this strongly connected component from
outside.  Then:

* when x1 is processed, state[x1] == .. == state[xn] == 0 independently
  of whatever else we did before.  So x1 gets marked and we set
  state[x1] = .. = state[xn] = 2.

* when x2, ... xn are processed, their state is != 0 so we do nothing.

* in the final loop, only x1 is marked and state[x1] == 2 so it stays
  marked.

Now, let's assume that x1 and x2 are not in the same strongly connected
component and there is a reference path from x1 to x2.  Then:

* if x1 is enumerated before x2, then x2 is in closure(x1) and so its
  state gets at least >= 2 when we process x1.  When we process x2 later
  we just skip it ("continue" line) and so it doesn't get marked.

* if x2 is enumerated before x1, then when we process x2 we mark it and
  set its state to >= 2 (before x2 is in closure(x2)), and then when we
  process x1 we set state[x2] == 3.  So in the final loop x2 gets
  removed from the "marked" list.

I think that it proves that the algorithm is doing what we want.

The next step is to remove the use of closure() in the algorithm in such
a way that the new algorithm has a reasonable performance -- linear in
the number of objects whose state it manipulates::

    marked = []
    for x in objects_with_finalizers:
        if state[x] != 0:
            continue
        marked.append(x)
        recursing on the objects y starting from x:
            if state[y] == 0:
                state[y] = 1
                follow y's children recursively
            elif state[y] == 2:
                state[y] = 3
                follow y's children recursively
            else:
                don't need to recurse inside y
        recursing on the objects y starting from x:
            if state[y] == 1:
                state[y] = 2
                follow y's children recursively
            else:
                don't need to recurse inside y
    for x in marked:
        assert state[x] >= 2
        if state[x] != 2:
            marked.remove(x)

In this algorithm we follow the children of each object at most 3 times,
when the state of the object changes from 0 to 1 to 2 to 3.  In a visit
that doesn't change the state of an object, we don't follow its children
recursively.

In practice, in the MiniMark GCs, we can encode
the 4 states with a combination of two bits in the header:

      =====  ==============  ============================
      state  GCFLAG_VISITED  GCFLAG_FINALIZATION_ORDERING
      =====  ==============  ============================
        0        no              no
        1        no              yes
        2        yes             yes
        3        yes             no
      =====  ==============  ============================

So the loop above that does the transition from state 1 to state 2 is
really just a recursive visit.  We must also clear the
FINALIZATION_ORDERING bit at the end (state 2 to state 3) to clean up
before the next collection.
