Application-level Stackless features
====================================

Introduction
------------

PyPy can expose to its user language features similar to the ones
present in `Stackless Python`_: the ability to write code in a
**massively concurrent style**.  (It does not (any more) offer the
ability to run with no `recursion depth limit`_, but the same effect
can be achieved indirectly.)

This feature is based on a custom primitive called a continulet_.
Continulets can be directly used by application code, or it is possible
to write (entirely at app-level) more user-friendly interfaces.

Currently PyPy implements greenlets_ on top of continulets.  It also
implements (an approximation of) tasklets and channels, emulating the model
of `Stackless Python`_.

Continulets are extremely light-weight, which means that PyPy should be
able to handle programs containing large amounts of them.  However, due
to an implementation restriction, a PyPy compiled with
``--gcrootfinder=shadowstack`` consumes at least one page of physical
memory (4KB) per live continulet, and half a megabyte of virtual memory
on 32-bit or a complete megabyte on 64-bit.  Moreover, the feature is
only available (so far) on x86 and x86-64 CPUs; for other CPUs you need
to add a short page of custom assembler to
:source:`rpython/translator/c/src/stacklet/`.

.. _Stackless Python: https://www.stackless.com


Theory
------

The fundamental idea is that, at any point in time, the program happens
to run one stack of frames (or one per thread, in case of
multi-threading).  To see the stack, start at the top frame and follow
the chain of ``f_back`` until you reach the bottom frame.  From the
point of view of one of these frames, it has a ``f_back`` pointing to
another frame (unless it is the bottom frame), and it is itself being
pointed to by another frame (unless it is the top frame).

The theory behind continulets is to literally take the previous sentence
as definition of "an O.K. situation".  The trick is that there are
O.K. situations that are more complex than just one stack: you will
always have one stack, but you can also have in addition one or more
detached *cycles* of frames, such that by following the ``f_back`` chain
you run in a circle.  But note that these cycles are indeed completely
detached: the top frame (the currently running one) is always the one
which is not the ``f_back`` of anybody else, and it is always the top of
a stack that ends with the bottom frame, never a part of these extra
cycles.

How do you create such cycles?  The fundamental operation to do so is to
take two frames and *permute* their ``f_back`` --- i.e. exchange them.
You can permute any two ``f_back`` without breaking the rule of "an O.K.
situation".  Say for example that ``f`` is some frame halfway down the
stack, and you permute its ``f_back`` with the ``f_back`` of the top
frame.  Then you have removed from the normal stack all intermediate
frames, and turned them into one stand-alone cycle.  By doing the same
permutation again you restore the original situation.

In practice, in PyPy, you cannot change the ``f_back`` of an abitrary
frame, but only of frames stored in ``continulets``.

Continulets are internally implemented using stacklets_.  Stacklets are a
bit more primitive (they are really one-shot continuations), but that
idea only works in C, not in Python.  The basic idea of continulets is
to have at any point in time a complete valid stack; this is important
e.g. to correctly propagate exceptions (and it seems to give meaningful
tracebacks too).


Application level interface
---------------------------

.. _continulet:

Continulets
~~~~~~~~~~~

A translated PyPy contains by default a module called ``_continuation``
exporting the type ``continulet``.  A ``continulet`` object from this
module is a container that stores a "one-shot continuation".  It plays
the role of an extra frame you can insert in the stack, and whose
``f_back`` can be changed.

To make a continulet object, call ``continulet()`` with a callable and
optional extra arguments.

Later, the first time you ``switch()`` to the continulet, the callable
is invoked with the same continulet object as the extra first argument.
At that point, the one-shot continuation stored in the continulet points
to the caller of ``switch()``.  In other words you have a perfectly
normal-looking stack of frames.  But when ``switch()`` is called again,
this stored one-shot continuation is exchanged with the current one; it
means that the caller of ``switch()`` is suspended with its continuation
stored in the container, and the old continuation from the continulet
object is resumed.

The most primitive API is actually 'permute()', which just permutes the
one-shot continuation stored in two (or more) continulets.

In more details:

* ``continulet(callable, *args, **kwds)``: make a new continulet.
  Like a generator, this only creates it; the ``callable`` is only
  actually called the first time it is switched to.  It will be
  called as follows::

      callable(cont, *args, **kwds)

  where ``cont`` is the same continulet object.

  Note that it is actually ``cont.__init__()`` that binds
  the continulet.  It is also possible to create a not-bound-yet
  continulet by calling explicitly ``continulet.__new__()``, and
  only bind it later by calling explicitly ``cont.__init__()``.

* ``cont.switch(value=None, to=None)``: start the continulet if
  it was not started yet.  Otherwise, store the current continuation
  in ``cont``, and activate the target continuation, which is the
  one that was previously stored in ``cont``.  Note that the target
  continuation was itself previously suspended by another call to
  ``switch()``; this older ``switch()`` will now appear to return.
  The ``value`` argument is any object that is carried to the target
  and returned by the target's ``switch()``.

  If ``to`` is given, it must be another continulet object.  In
  that case, performs a "double switch": it switches as described
  above to ``cont``, and then immediately switches again to ``to``.
  This is different from switching directly to ``to``: the current
  continuation gets stored in ``cont``, the old continuation from
  ``cont`` gets stored in ``to``, and only then we resume the
  execution from the old continuation out of ``to``.

* ``cont.throw(type, value=None, tb=None, to=None)``: similar to
  ``switch()``, except that immediately after the switch is done, raise
  the given exception in the target.

* ``cont.is_pending()``: return True if the continulet is pending.
  This is False when it is not initialized (because we called
  ``__new__`` and not ``__init__``) or when it is finished (because
  the ``callable()`` returned).  When it is False, the continulet
  object is empty and cannot be ``switch()``-ed to.

* ``permute(*continulets)``: a global function that permutes the
  continuations stored in the given continulets arguments.  Mostly
  theoretical.  In practice, using ``cont.switch()`` is easier and
  more efficient than using ``permute()``; the latter does not on
  its own change the currently running frame.


Genlets
~~~~~~~

The ``_continuation`` module also exposes the ``generator`` decorator::

    @generator
    def f(cont, a, b):
        cont.switch(a + b)
        cont.switch(a + b + 1)

    for i in f(10, 20):
        print i

This example prints 30 and 31.  The only advantage over using regular
generators is that the generator itself is not limited to ``yield``
statements that must all occur syntactically in the same function.
Instead, we can pass around ``cont``, e.g. to nested sub-functions, and
call ``cont.switch(x)`` from there.

The ``generator`` decorator can also be applied to methods::

    class X:
        @generator
        def f(self, cont, a, b):
            ...


Greenlets
~~~~~~~~~

Greenlets are implemented on top of continulets in :source:`lib_pypy/greenlet.py`.
See the official `documentation of the greenlets`_.

Note that unlike the CPython greenlets, this version does not suffer
from GC issues: if the program "forgets" an unfinished greenlet, it will
always be collected at the next garbage collection.

.. _documentation of the greenlets: https://greenlet.readthedocs.io/


Unimplemented features
~~~~~~~~~~~~~~~~~~~~~~

The following features (present in some past Stackless version of PyPy)
are for the time being not supported any more:

* Coroutines (could be rewritten at app-level)

* Continuing execution of a continulet in a different thread
  (but if it is "simple enough", you can pickle it and unpickle it
  in the other thread).

* Automatic unlimited stack (must be emulated__ so far)

* Support for other CPUs than x86 and x86-64

.. __: `recursion depth limit`_

We also do not include any of the recent API additions to Stackless
Python, like ``set_atomic()``.  Contributions welcome.


Recursion depth limit
~~~~~~~~~~~~~~~~~~~~~

You can use continulets to emulate the infinite recursion depth present
in Stackless Python and in stackless-enabled older versions of PyPy.

The trick is to start a continulet "early", i.e. when the recursion
depth is very low, and switch to it "later", i.e. when the recursion
depth is high.  Example::

    from _continuation import continulet

    def invoke(_, callable, arg):
        return callable(arg)

    def bootstrap(c):
        # this loop runs forever, at a very low recursion depth
        callable, arg = c.switch()
        while True:
            # start a new continulet from here, and switch to
            # it using an "exchange", i.e. a switch with to=.
            to = continulet(invoke, callable, arg)
            callable, arg = c.switch(to=to)

    c = continulet(bootstrap)
    c.switch()


    def recursive(n):
        if n == 0:
            return ("ok", n)
        if n % 200 == 0:
            prev = c.switch((recursive, n - 1))
        else:
            prev = recursive(n - 1)
        return (prev[0], prev[1] + 1)

    print recursive(999999)     # prints ('ok', 999999)

Note that if you press Ctrl-C while running this example, the traceback
will be built with *all* recursive() calls so far, even if this is more
than the number that can possibly fit in the C stack.  These frames are
"overlapping" each other in the sense of the C stack; more precisely,
they are copied out of and into the C stack as needed.

(The example above also makes use of the following general "guideline"
to help newcomers write continulets: in ``bootstrap(c)``, only call
methods on ``c``, not on another continulet object.  That's why we wrote
``c.switch(to=to)`` and not ``to.switch()``, which would mess up the
state.  This is however just a guideline; in general we would recommend
to use other interfaces like genlets and greenlets.)


Stacklets
~~~~~~~~~

Continulets are internally implemented using stacklets, which is the
generic RPython-level building block for "one-shot continuations".  For
more information about them please see the documentation in the C source
at :source:`rpython/translator/c/src/stacklet/stacklet.h`.

The module ``rpython.rlib.rstacklet`` is a thin wrapper around the above
functions.  The key point is that new() and switch() always return a
fresh stacklet handle (or an empty one), and switch() additionally
consumes one.  It makes no sense to have code in which the returned
handle is ignored, or used more than once.  Note that ``stacklet.c`` is
written assuming that the user knows that, and so no additional checking
occurs; this can easily lead to obscure crashes if you don't use a
wrapper like PyPy's '_continuation' module.


Theory of composability
~~~~~~~~~~~~~~~~~~~~~~~

Although the concept of coroutines is far from new, they have not been
generally integrated into mainstream languages, or only in limited form
(like generators in Python and iterators in C#).  We can argue that a
possible reason for that is that they do not scale well when a program's
complexity increases: they look attractive in small examples, but the
models that require explicit switching, for example by naming the target
coroutine, do not compose naturally.  This means that a program that
uses coroutines for two unrelated purposes may run into conflicts caused
by unexpected interactions.

To illustrate the problem, consider the following example (simplified
code using a theorical ``coroutine`` class).  First, a simple usage of
coroutine::

    main_coro = coroutine.getcurrent()    # the main (outer) coroutine
    data = []

    def data_producer():
        for i in range(10):
            # add some numbers to the list 'data' ...
            data.append(i)
            data.append(i * 5)
            data.append(i * 25)
            # and then switch back to main to continue processing
            main_coro.switch()

    producer_coro = coroutine()
    producer_coro.bind(data_producer)

    def grab_next_value():
        if not data:
            # put some more numbers in the 'data' list if needed
            producer_coro.switch()
        # then grab the next value from the list
        return data.pop(0)

Every call to grab_next_value() returns a single value, but if necessary
it switches into the producer function (and back) to give it a chance to
put some more numbers in it.

Now consider a simple reimplementation of Python's generators in term of
coroutines::

    def generator(f):
        """Wrap a function 'f' so that it behaves like a generator."""
        def wrappedfunc(*args, **kwds):
            g = generator_iterator()
            g.bind(f, *args, **kwds)
            return g
        return wrappedfunc

    class generator_iterator(coroutine):
        def __iter__(self):
            return self
        def next(self):
            self.caller = coroutine.getcurrent()
            self.switch()
            return self.answer

    def Yield(value):
        """Yield the value from the current generator."""
        g = coroutine.getcurrent()
        g.answer = value
        g.caller.switch()

    def squares(n):
        """Demo generator, producing square numbers."""
        for i in range(n):
            Yield(i * i)
    squares = generator(squares)

    for x in squares(5):
        print x       # this prints 0, 1, 4, 9, 16

Both these examples are attractively elegant.  However, they cannot be
composed.  If we try to write the following generator::

    def grab_values(n):
        for i in range(n):
            Yield(grab_next_value())
    grab_values = generator(grab_values)

then the program does not behave as expected.  The reason is the
following.  The generator coroutine that executes ``grab_values()``
calls ``grab_next_value()``, which may switch to the ``producer_coro``
coroutine.  This works so far, but the switching back from
``data_producer()`` to ``main_coro`` lands in the wrong coroutine: it
resumes execution in the main coroutine, which is not the one from which
it comes.  We expect ``data_producer()`` to switch back to the
``grab_next_values()`` call, but the latter lives in the generator
coroutine ``g`` created in ``wrappedfunc``, which is totally unknown to
the ``data_producer()`` code.  Instead, we really switch back to the
main coroutine, which confuses the ``generator_iterator.next()`` method
(it gets resumed, but not as a result of a call to ``Yield()``).

Thus the notion of coroutine is *not composable*.  By opposition, the
primitive notion of continulets is composable: if you build two
different interfaces on top of it, or have a program that uses twice the
same interface in two parts, then assuming that both parts independently
work, the composition of the two parts still works.

A full proof of that claim would require careful definitions, but let us
just claim that this fact is true because of the following observation:
the API of continulets is such that, when doing a ``switch()``, it
requires the program to have some continulet to explicitly operate on.
It shuffles the current continuation with the continuation stored in
that continulet, but has no effect outside.  So if a part of a program
has a continulet object, and does not expose it as a global, then the
rest of the program cannot accidentally influence the continuation
stored in that continulet object.

In other words, if we regard the continulet object as being essentially
a modifiable ``f_back``, then it is just a link between the frame of
``callable()`` and the parent frame --- and it cannot be arbitrarily
changed by unrelated code, as long as they don't explicitly manipulate
the continulet object.  Typically, both the frame of ``callable()``
(commonly a local function) and its parent frame (which is the frame
that switched to it) belong to the same class or module; so from that
point of view the continulet is a purely local link between two local
frames.  It doesn't make sense to have a concept that allows this link
to be manipulated from outside.
