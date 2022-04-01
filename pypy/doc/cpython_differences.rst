Differences between PyPy and CPython
====================================

This page documents the few differences and incompatibilities between
the PyPy Python interpreter and CPython.  Some of these differences
are "by design", since we think that there are cases in which the
behaviour of CPython is buggy, and we do not want to copy bugs.

Differences that are not listed here should be considered bugs of
PyPy.



Differences related to garbage collection strategies
----------------------------------------------------

The garbage collectors used or implemented by PyPy are not based on
reference counting, so the objects are not freed instantly when they are no
longer reachable.  The most obvious effect of this is that files (and sockets, etc) are not
promptly closed when they go out of scope.  For files that are opened for
writing, data can be left sitting in their output buffers for a while, making
the on-disk file appear empty or truncated.  Moreover, you might reach your
OS's limit on the number of concurrently opened files.

If you are debugging a case where a file in your program is not closed
properly on PyPy2, you can use the ``-X track-resources`` command line
option. On Python3 (both CPython and PyPy), use the ``-Walways`` command line
option. In both cases, you may need to add a call to ``gc.collect()`` at the
end of the program. Then a ``ResourceWarning`` is produced for every file and
socket that the garbage collector closes. On PyPy, the warning will always
contain the stack trace of the position where the file or socket was created,
to make it easier to see which parts of the program don't close files
explicitly.

Fixing this difference to CPython is essentially impossible without forcing a
reference-counting approach to garbage collection.  The effect that you
get in CPython has clearly been described as a side-effect of the
implementation and not a language design decision: programs relying on
this are basically bogus.  It would be a too strong restriction to try to enforce
CPython's behavior in a language spec, given that it has no chance to be
adopted by Jython or IronPython (or any other port of Python to Java or
.NET).

Even the naive idea of forcing a full GC when we're getting dangerously
close to the OS's limit can be very bad in some cases.  If your program
leaks open files heavily, then it would work, but force a complete GC
cycle every n'th leaked file.  The value of n is a constant, but the
program can take an arbitrary amount of memory, which makes a complete
GC cycle arbitrarily long.  The end result is that PyPy would spend an
arbitrarily large fraction of its run time in the GC --- slowing down
the actual execution, not by 10% nor 100% nor 1000% but by essentially
any factor.

To the best of our knowledge this problem has no better solution than
fixing the programs.  If it occurs in 3rd-party code, this means going
to the authors and explaining the problem to them: they need to close
their open files in order to run on any non-CPython-based implementation
of Python.

---------------------------------

Here are some more technical details.  This issue affects the precise
time at which ``__del__`` methods are called, which
is not reliable or timely in PyPy (nor Jython nor IronPython).  It also means that
**weak references** may stay alive for a bit longer than expected.  This
makes "weak proxies" (as returned by ``weakref.proxy()``) somewhat less
useful: they will appear to stay alive for a bit longer in PyPy, and
suddenly they will really be dead, raising a ``ReferenceError`` on the
next access.  Any code that uses weak proxies must carefully catch such
``ReferenceError`` at any place that uses them.  (Or, better yet, don't use
``weakref.proxy()`` at all; use ``weakref.ref()``.)

Note a detail in the `documentation for weakref callbacks`__:

    If callback is provided and not None, *and the returned weakref
    object is still alive,* the callback will be called when the object
    is about to be finalized.

There are cases where, due to CPython's refcount semantics, a weakref
dies immediately before or after the objects it points to (typically
with some circular reference).  If it happens to die just after, then
the callback will be invoked.  In a similar case in PyPy, both the
object and the weakref will be considered as dead at the same time,
and the callback will not be invoked.  (Issue `#2030`__)

.. __: https://docs.python.org/2/library/weakref.html
.. __: https://foss.heptapod.net/pypy/pypy/issue/2030/

A new difference: before CPython 3.4, a weakref to ``x`` was always
cleared before the ``x.__del__()`` method was called.  Since CPython 3.4
the picture is more muddy.  Often, the weakref is still alive while
``x.__del__()`` runs, but not always (e.g. not in case of reference
cycles).  In PyPy3 we have kept the more consistent pre-3.4 behavior; we
can't do something really different if there are cycles or not.

---------------------------------

There are a few extra implications from the difference in the GC.  Most
notably, if an object has a ``__del__``, the ``__del__`` is never called more
than once in PyPy; but CPython will call the same ``__del__`` several times
if the object is resurrected and dies again (at least it is reliably so in
older CPythons; newer CPythons try to call destructors not more than once,
but there are counter-examples).  The ``__del__`` methods are
called in "the right" order if they are on objects pointing to each
other, as in CPython, but unlike CPython, if there is a dead cycle of
objects referencing each other, their ``__del__`` methods are called anyway;
CPython would instead put them into the list ``garbage`` of the ``gc``
module.  More information is available on the blog `[1]`__ `[2]`__.

.. __: https://morepypy.blogspot.com/2008/02/python-finalizers-semantics-part-1.html
.. __: https://morepypy.blogspot.com/2008/02/python-finalizers-semantics-part-2.html

Note that this difference might show up indirectly in some cases.  For
example, a generator left pending in the middle is --- again ---
garbage-collected later in PyPy than in CPython.  You can see the
difference if the ``yield`` keyword it is suspended at is itself
enclosed in a ``try:`` or a ``with:`` block.  This shows up for example
as `issue 736`__.

.. __: https://bugs.pypy.org/issue736

Using the default GC (called ``minimark``), the built-in function ``id()``
works like it does in CPython.  With other GCs it returns numbers that
are not real addresses (because an object can move around several times)
and calling it a lot can lead to performance problem.

Note that if you have a long chain of objects, each with a reference to
the next one, and each with a ``__del__``, PyPy's GC will perform badly.  On
the bright side, in most other cases, benchmarks have shown that PyPy's
GCs perform much better than CPython's.

Another difference is that if you add a ``__del__`` to an existing class it will
not be called::

    >>>> class A(object):
    ....     pass
    ....
    >>>> A.__del__ = lambda self: None
    __main__:1: RuntimeWarning: a __del__ method added to an existing type will not be called

Even more obscure: the same is true, for old-style classes, if you attach
the ``__del__`` to an instance (even in CPython this does not work with
new-style classes).  You get a RuntimeWarning in PyPy.  To fix these cases
just make sure there is a ``__del__`` method in the class to start with
(even containing only ``pass``; replacing or overriding it later works fine).

Last note: CPython tries to do a ``gc.collect()`` automatically when the
program finishes; not PyPy.  (It is possible in both CPython and PyPy to
design a case where several ``gc.collect()`` are needed before all objects
die.  This makes CPython's approach only work "most of the time" anyway.)


Subclasses of built-in types
----------------------------

Officially, CPython has no rule at all for when exactly
overridden method of subclasses of built-in types get
implicitly called or not.  As an approximation, these methods
are never called by other built-in methods of the same object.
For example, an overridden ``__getitem__()`` in a subclass of
``dict`` will not be called by e.g. the built-in ``get()``
method.

The above is true both in CPython and in PyPy.  Differences
can occur about whether a built-in function or method will
call an overridden method of *another* object than ``self``.
In PyPy, they are often called in cases where CPython would not.
Two examples::

    class D(dict):
        def __getitem__(self, key):
            if key == 'print':
                return print
            return "%r from D" % (key,)

    class A(object):
        pass

    a = A()
    a.__dict__ = D()
    a.foo = "a's own foo"
    print(a.foo)
    # CPython => a's own foo
    # PyPy => 'foo' from D

    print('==========')

    glob = D(foo="base item")
    loc = {}
    exec("print(foo)", glob, loc)
    # CPython => base item, and never looks up "print" in D
    # PyPy => 'foo' from D, and looks up "print" in D


Mutating classes of objects which are already used as dictionary keys
---------------------------------------------------------------------

Consider the following snippet of code::

    class X(object):
        pass

    def __evil_eq__(self, other):
        print 'hello world'
        return False

    def evil(y):
        d = {X(): 1}
        X.__eq__ = __evil_eq__
        d[y] # might trigger a call to __eq__?

In CPython, __evil_eq__ **might** be called, although there is no way to write
a test which reliably calls it.  It happens if ``y is not x`` and ``hash(y) ==
hash(x)``, where ``hash(x)`` is computed when ``x`` is inserted into the
dictionary.  If **by chance** the condition is satisfied, then ``__evil_eq__``
is called.

PyPy uses a special strategy to optimize dictionaries whose keys are instances
of user-defined classes which do not override the default ``__hash__``,
``__eq__`` and ``__cmp__``: when using this strategy, ``__eq__`` and
``__cmp__`` are never called, but instead the lookup is done by identity, so
in the case above it is guaranteed that ``__eq__`` won't be called.

Note that in all other cases (e.g., if you have a custom ``__hash__`` and
``__eq__`` in ``y``) the behavior is exactly the same as CPython.


Ignored exceptions
-----------------------

In many corner cases, CPython can silently swallow exceptions.
The precise list of when this occurs is rather long, even
though most cases are very uncommon.  The most well-known
places are custom rich comparison methods (like \_\_eq\_\_);
dictionary lookup; calls to some built-in functions like
isinstance().

Unless this behavior is clearly present by design and
documented as such (as e.g. for hasattr()), in most cases PyPy
lets the exception propagate instead.


Object Identity of Primitive Values, ``is`` and ``id``
-------------------------------------------------------

Object identity of primitive values works by value equality, not by identity of
the wrapper. This means that ``x + 1 is x + 1`` is always true, for arbitrary
integers ``x``. The rule applies for the following types:

 - ``int``

 - ``float``

 - ``long``

 - ``complex``

 - ``str`` (empty or single-character strings only)

 - ``unicode`` (empty or single-character strings only)

 - ``tuple`` (empty tuples only)

 - ``frozenset`` (empty frozenset only)

 - unbound method objects (for Python 2 only)

This change requires some changes to ``id`` as well. ``id`` fulfills the
following condition: ``x is y <=> id(x) == id(y)``. Therefore ``id`` of the
above types will return a value that is computed from the argument, and can
thus be larger than ``sys.maxint`` (i.e. it can be an arbitrary long).

Note that strings of length 2 or greater can be equal without being
identical.  Similarly, ``x is (2,)`` is not necessarily true even if
``x`` contains a tuple and ``x == (2,)``.  The uniqueness rules apply
only to the particular cases described above.  The ``str``, ``unicode``,
``tuple`` and ``frozenset`` rules were added in PyPy 5.4; before that, a
test like ``if x is "?"`` or ``if x is ()`` could fail even if ``x`` was
equal to ``"?"`` or ``()``.  The new behavior added in PyPy 5.4 is
closer to CPython's, which caches precisely the empty tuple/frozenset,
and (generally but not always) the strings and unicodes of length <= 1.

Note that for floats there "``is``" only one object per "bit pattern"
of the float.  So ``float('nan') is float('nan')`` is true on PyPy,
but not on CPython because they are two objects; but ``0.0 is -0.0``
is always False, as the bit patterns are different.  As usual,
``float('nan') == float('nan')`` is always False.  When used in
containers (as list items or in sets for example), the exact rule of
equality used is "``if x is y or x == y``" (on both CPython and PyPy);
as a consequence, because all ``nans`` are identical in PyPy, you
cannot have several of them in a set, unlike in CPython.  (Issue `#1974`__).
Another consequence is that ``cmp(float('nan'), float('nan')) == 0``, because
``cmp`` checks with ``is`` first whether the arguments are identical (there is
no good value to return from this call to ``cmp``, because ``cmp`` pretends
that there is a total order on floats, but that is wrong for NaNs).

.. __: https://foss.heptapod.net/pypy/pypy/issue/1974/different-behaviour-for-collections-of

C-API Differences
-----------------

The external C-API has been reimplemented in PyPy as an internal cpyext module.
We support most of the documented C-API, but sometimes internal C-abstractions
leak out on CPython and are abused, perhaps even unknowingly. For instance,
assignment to a ``PyTupleObject`` is not supported after the tuple is
used internally, even by another C-API function call. On CPython this will
succeed as long as the refcount is 1.  On PyPy this will always raise a
``SystemError('PyTuple_SetItem called on tuple after  use of tuple")``
exception (explicitly listed here for search engines).

Another similar problem is assignment of a new function pointer to any of the
``tp_as_*`` structures after calling ``PyType_Ready``. For instance, overriding
``tp_as_number.nb_int`` with a different function after calling ``PyType_Ready``
on CPython will result in the old function being called for ``x.__int__()``
(via class ``__dict__`` lookup) and the new function being called for ``int(x)``
(via slot lookup). On PyPy we will always call the __new__ function, not the
old, this quirky behaviour is unfortunately necessary to fully support NumPy.

Performance Differences
-------------------------

CPython has an optimization that can make repeated string concatenation not
quadratic. For example, this kind of code runs in O(n) time::

    s = ''
    for string in mylist:
        s += string

In PyPy, this code will always have quadratic complexity. Note also, that the
CPython optimization is brittle and can break by having slight variations in
your code anyway. So you should anyway replace the code with::

    parts = []
    for string in mylist:
        parts.append(string)
    s = "".join(parts)

Miscellaneous
-------------

* Hash randomization (``-R``) `is ignored in PyPy`_.  In CPython
  before 3.4 it has `little point`_.  Both CPython >= 3.4 and PyPy3
  implement the randomized SipHash algorithm and ignore ``-R``.

* You can't store non-string keys in type objects.  For example::

    class A(object):
        locals()[42] = 3

  won't work.

* ``sys.setrecursionlimit(n)`` sets the limit only approximately,
  by setting the usable stack space to ``n * 768`` bytes.  On Linux,
  depending on the compiler settings, the default of 768KB is enough
  for about 1400 calls.

* since the implementation of dictionary is different, the exact number
  of times that ``__hash__`` and ``__eq__`` are called is different. 
  Since CPython
  does not give any specific guarantees either, don't rely on it.

* assignment to ``__class__`` is limited to the cases where it
  works on CPython 2.5.  On CPython 2.6 and 2.7 it works in a bit
  more cases, which are not supported by PyPy so far.  (If needed,
  it could be supported, but then it will likely work in many
  *more* case on PyPy than on CPython 2.6/2.7.)

* the ``__builtins__`` name is always referencing the ``__builtin__`` module,
  never a dictionary as it sometimes is in CPython. Assigning to
  ``__builtins__`` has no effect.  (For usages of tools like
  RestrictedPython, see `issue #2653`_.)

* directly calling the internal magic methods of a few built-in types
  with invalid arguments may have a slightly different result.  For
  example, ``[].__add__(None)`` and ``(2).__add__(None)`` both return
  ``NotImplemented`` on PyPy; on CPython, only the latter does, and the
  former raises ``TypeError``.  (Of course, ``[]+None`` and ``2+None``
  both raise ``TypeError`` everywhere.)  This difference is an
  implementation detail that shows up because of internal C-level slots
  that PyPy does not have.

* on CPython, ``[].__add__`` is a ``method-wrapper``,  ``list.__add__``
  is a ``slot wrapper`` and ``list.extend``  is a (built-in) ``method``
  object.  On PyPy these are all normal method or function objects (or
  unbound method objects on PyPy2).  This can occasionally confuse some
  tools that inspect built-in types.  For example, the standard
  library ``inspect`` module has a function ``ismethod()`` that returns
  True on unbound method objects but False on method-wrappers or slot
  wrappers.  On PyPy we can't tell the difference.  So on PyPy2 we
  have ``ismethod([].__add__) == ismethod(list.extend) == True``;
  on PyPy3 we have ``isfunction(list.extend) == True``.  On CPython
  all of these are False.

* in CPython, the built-in types have attributes that can be
  implemented in various ways.  Depending on the way, if you try to
  write to (or delete) a read-only (or undeletable) attribute, you get
  either a ``TypeError`` or an ``AttributeError``.  PyPy tries to
  strike some middle ground between full consistency and full
  compatibility here.  This means that a few corner cases don't raise
  the same exception, like ``del (lambda:None).__closure__``.

* in pure Python, if you write ``class A(object): def f(self): pass``
  and have a subclass ``B`` which doesn't override ``f()``, then
  ``B.f(x)`` still checks that ``x`` is an instance of ``B``.  In
  CPython, types written in C use a different rule.  If ``A`` is
  written in C, any instance of ``A`` will be accepted by ``B.f(x)``
  (and actually, ``B.f is A.f`` in this case).  Some code that could
  work on CPython but not on PyPy includes:
  ``datetime.datetime.strftime(datetime.date.today(), ...)`` (here,
  ``datetime.date`` is the superclass of ``datetime.datetime``).
  Anyway, the proper fix is arguably to use a regular method call in
  the first place: ``datetime.date.today().strftime(...)``
  
* some functions and attributes of the ``gc`` module behave in a
  slightly different way: for example, ``gc.enable`` and
  ``gc.disable`` are supported, but "enabling and disabling the GC" has
  a different meaning in PyPy than in CPython.  These functions
  actually enable and disable the major collections and the
  execution of finalizers.

* PyPy prints a random line from past #pypy IRC topics at startup in
  interactive mode. In a released version, this behaviour is suppressed, but
  setting the environment variable PYPY_IRC_TOPIC will bring it back. Note that
  downstream package providers have been known to totally disable this feature.

* PyPy's readline module was rewritten from scratch: it is not GNU's
  readline.  It should be mostly compatible, and it adds multiline
  support (see ``multiline_input()``).  On the other hand,
  ``parse_and_bind()`` calls are ignored (issue `#2072`_).

* ``sys.getsizeof()`` always raises ``TypeError``.  This is because a
  memory profiler using this function is most likely to give results
  inconsistent with reality on PyPy.  It would be possible to have
  ``sys.getsizeof()`` return a number (with enough work), but that may
  or may not represent how much memory the object uses.  It doesn't even
  make really sense to ask how much *one* object uses, in isolation with
  the rest of the system.  For example, instances have maps, which are
  often shared across many instances; in this case the maps would
  probably be ignored by an implementation of ``sys.getsizeof()``, but
  their overhead is important in some cases if they are many instances
  with unique maps.  Conversely, equal strings may share their internal
  string data even if they are different objects---even a unicode string
  and its utf8-encoded ``bytes`` version are shared---or empty containers
  may share parts of their internals as long as they are empty.  Even
  stranger, some lists create objects as you read them; if you try to
  estimate the size in memory of ``range(10**6)`` as the sum of all
  items' size, that operation will by itself create one million integer
  objects that never existed in the first place.  Note that some of
  these concerns also exist on CPython, just less so.  For this reason
  we explicitly don't implement ``sys.getsizeof()``.

* The ``timeit`` module behaves differently under PyPy: it prints the average
  time and the standard deviation, instead of the minimum, since the minimum is
  often misleading.

* The ``get_config_vars`` method of ``sysconfig`` and ``distutils.sysconfig``
  are not complete. On POSIX platforms, CPython fishes configuration variables
  from the Makefile used to build the interpreter. PyPy should bake the values
  in during compilation, but does not do that yet.

* CPython's ``sys.settrace()`` sometimes reports an ``exception`` at the
  end of ``for`` or ``yield from`` lines for the ``StopIteration``, and
  sometimes not.  The problem is that it occurs in an ill-defined subset
  of cases.  PyPy attempts to emulate that but the precise set of cases
  is not exactly the same.

* ``"%d" % x`` and ``"%x" % x`` and similar constructs, where ``x`` is
  an instance of a subclass of ``long`` that overrides the special
  methods ``__str__`` or ``__hex__`` or ``__oct__``: PyPy doesn't call
  the special methods; CPython does---but only if it is a subclass of
  ``long``, not ``int``.  CPython's behavior is really messy: e.g. for
  ``%x`` it calls ``__hex__()``, which is supposed to return a string
  like ``-0x123L``; then the ``0x`` and the final ``L`` are removed, and
  the rest is kept.  If you return an unexpected string from
  ``__hex__()`` you get an exception (or a crash before CPython 2.7.13).

* In PyPy, dictionaries passed as ``**kwargs`` can contain only string keys,
  even for ``dict()`` and ``dict.update()``.  CPython 2.7 allows non-string
  keys in these two cases (and only there, as far as we know).  E.g. this
  code produces a ``TypeError``, on CPython 3.x as well as on any PyPy:
  ``dict(**{1: 2})``.  (Note that ``dict(**d1)`` is equivalent to
  ``dict(d1)``.)

* PyPy3: ``__class__`` attribute assignment between heaptypes and non heaptypes.
  CPython allows that for module subtypes, but not for e.g. ``int``
  or ``float`` subtypes. Currently PyPy does not support the
  ``__class__`` attribute assignment for any non heaptype subtype.

* In PyPy, module and class dictionaries are optimized under the assumption
  that deleting attributes from them are rare. Because of this, e.g.
  ``del foo.bar`` where ``foo`` is a module (or class) that contains the
  function ``bar``, is significantly slower than CPython.

* Various built-in functions in CPython accept only positional arguments
  and not keyword arguments.  That can be considered a long-running
  historical detail: newer functions tend to accept keyword arguments
  and older function are occasionally fixed to do so as well.  In PyPy,
  most built-in functions accept keyword arguments (``help()`` shows the
  argument names).  But don't rely on it too much because future
  versions of PyPy may have to rename the arguments if CPython starts
  accepting them too.

* PyPy3: ``distutils`` has been enhanced to allow finding ``VsDevCmd.bat`` in the
  directory pointed to by the ``VS%0.f0COMNTOOLS`` (typically ``VS140COMNTOOLS``)
  environment variable. CPython searches for ``vcvarsall.bat`` somewhere **above**
  that value.

* SyntaxError_ s try harder to give details about the cause of the failure, so
  the error messages are not the same as in CPython

* Dictionaries and sets are ordered on PyPy.  On CPython < 3.6 they are not;
  on CPython >= 3.6 dictionaries (but not sets) are ordered.

* PyPy2 refuses to load lone ``.pyc`` files, i.e. ``.pyc`` files that are
  still there after you deleted the ``.py`` file.  PyPy3 instead behaves like
  CPython.  We could be amenable to fix this difference in PyPy2: the current
  version reflects `our annoyance`__ with this detail of CPython, which bit
  us too often while developing PyPy.  (It is as easy as passing the
  ``--lonepycfile`` flag when translating PyPy, if you really need it.)

.. __: https://stackoverflow.com/a/55499713/1556290


.. _extension-modules:

Extension modules
-----------------

List of extension modules that we support:

* Supported as built-in modules (in :source:`pypy/module/`):

    __builtin__
    :doc:`__pypy__ <__pypy__-module>`
    _ast
    _codecs
    _collections
    :doc:`_continuation <stackless>`
    :doc:`_ffi <discussion/ctypes-implementation>`
    _hashlib
    _io
    _locale
    _lsprof
    _md5
    :doc:`_minimal_curses <config/objspace.usemodules._minimal_curses>`
    _multiprocessing
    _random
    :doc:`_rawffi <discussion/ctypes-implementation>`
    _sha
    _socket
    _sre
    _ssl
    _warnings
    _weakref
    _winreg
    array
    binascii
    bz2
    cStringIO
    cmath
    `cpyext`_
    crypt
    errno
    exceptions
    fcntl
    gc
    imp
    itertools
    marshal
    math
    mmap
    operator
    parser
    posix
    pyexpat
    select
    signal
    struct
    symbol
    sys
    termios
    thread
    time
    token
    unicodedata
    zlib

  When translated on Windows, a few Unix-only modules are skipped,
  and the following module is built instead:

    _winreg

* Supported by being rewritten in pure Python (possibly using ``cffi``):
  see the :source:`lib_pypy/` directory.  Examples of modules that we
  support this way: ``ctypes``, ``cPickle``, ``cmath``, ``dbm``, ``datetime``...
  Note that some modules are both in there and in the list above;
  by default, the built-in module is used (but can be disabled
  at translation time).

The extension modules (i.e. modules written in C, in the standard CPython)
that are neither mentioned above nor in :source:`lib_pypy/` are not available in PyPy.
(You may have a chance to use them anyway with `cpyext`_.)

.. _cpyext: https://morepypy.blogspot.com/2010/04/using-cpython-extension-modules-with.html


.. _`is ignored in PyPy`: https://bugs.python.org/issue14621
.. _`little point`: https://events.ccc.de/congress/2012/Fahrplan/events/5152.en.html
.. _`#2072`: https://foss.heptapod.net/pypy/pypy/issue/2072/
.. _`issue #2653`: https://foss.heptapod.net/pypy/pypy/issues/2653/
.. _SyntaxError: https://morepypy.blogspot.co.il/2018/04/improving-syntaxerror-in-pypy.html
