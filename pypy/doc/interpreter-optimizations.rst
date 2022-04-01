Standard Interpreter Optimizations
==================================

.. contents::

Introduction
------------

One of the advantages -- indeed, one of the motivating goals -- of the PyPy
standard interpreter (compared to CPython) is that of increased flexibility and
configurability.

One example of this is that we can provide several implementations of the same
object (e.g. lists) without exposing any difference to application-level
code. This makes it easy to provide a specialized implementation of a type that
is optimized for a certain situation without disturbing the implementation for
the regular case.

This document describes several such optimizations.  Most of them are not
enabled by default.  Also, for many of these optimizations it is not clear
whether they are worth it in practice for a real-world application (they sure
make some microbenchmarks a lot faster and use less memory, which is not saying
too much).  If you have any observation in that direction, please let us know!
By the way: alternative object implementations are a great way to get into PyPy
development since you have to know only a rather small part of PyPy to do
them. And they are fun too!

.. describe other optimizations!


Object Optimizations
--------------------

Integer Optimizations
~~~~~~~~~~~~~~~~~~~~~

Caching Small Integers
++++++++++++++++++++++

Similar to CPython, it is possible to enable caching of small integer objects to
not have to allocate all the time when doing simple arithmetic. Every time a new
integer object is created it is checked whether the integer is small enough to
be retrieved from the cache.

This option is disabled by default, you can enable this feature with the
:config:`objspace.std.withprebuiltint` option.


Integers as Tagged Pointers
+++++++++++++++++++++++++++

An even more aggressive way to save memory when using integers is "small int"
integer implementation. It is another integer implementation used for integers
that only needs 31 bits (or 63 bits on a 64 bit machine). These integers
are represented as tagged pointers by setting their lowest bits to distinguish
them from normal pointers. This completely avoids the boxing step, saving
time and memory.

You can enable this feature with the :config:`objspace.std.withsmalllong` option.


Dictionary Optimizations
~~~~~~~~~~~~~~~~~~~~~~~~

Dict Strategies
++++++++++++++++

Dict strategies are an implementation approach for dictionaries (and lists)
that make it possible to use a specialized representation of the dictionary's
data, while still being able to switch back to a general representation should
that become necessary later.

Dict strategies are always enabled, by default there are special strategies for
dicts with just string keys, just unicode keys and just integer keys. If one of
those specialized strategies is used, then dict lookup can use much faster
hashing and comparison for the dict keys. There is of course also a strategy
for general keys.


Identity Dicts
+++++++++++++++

We also have a strategy specialized for keys that are instances of classes
which compares "by identity", which is the default unless you override
``__hash__``, ``__eq__`` or ``__cmp__``.  This strategy will be used only with
new-style classes.


Map Dicts
+++++++++++++

Map dictionaries are a special representation used together with dict strategies.
This dict strategy is used only for instance dictionaries and tries to
make instance dictionaries use less memory (in fact, usually memory behaviour
should be mostly like that of using ``__slots__``).

The idea is the following: Most instances of the same class have very similar
attributes, and are even adding these keys to the dictionary in the same order
while ``__init__()`` is being executed. That means that all the dictionaries of
these instances look very similar: they have the same set of keys with different
values per instance. What sharing dicts do is store these common keys into a
common structure object and thus save the space in the individual instance
dicts:
the representation of the instance dict contains only a list of values.



User Class Optimizations
~~~~~~~~~~~~~~~~~~~~~~~~

Method Caching
++++++++++++++

A method cache is introduced where the result of a method lookup
is stored (which involves potentially many lookups in the base classes of a
class). Entries in the method cache are stored using a hash computed from
the name being looked up, the call site (i.e. the bytecode object and
the current program counter), and a special "version" of the type where the
lookup happens (this version is incremented every time the type or one of its
base classes is changed). On subsequent lookups the cached version can be used,
as long as the instance did not shadow any of its classes attributes.

This feature is enabled by default.


Interpreter Optimizations
-------------------------

Special Bytecodes
~~~~~~~~~~~~~~~~~

.. _lookup method call method:

LOOKUP_METHOD & CALL_METHOD
+++++++++++++++++++++++++++

An unusual feature of Python's version of object oriented programming is the
concept of a "bound method".  While the concept is clean and powerful, the
allocation and initialization of the object is not without its performance cost.
We have implemented a pair of bytecodes that alleviate this cost.

For a given method call ``obj.meth(x, y)``, the standard bytecode looks like
this::

    LOAD_GLOBAL     obj      # push 'obj' on the stack
    LOAD_ATTR       meth     # read the 'meth' attribute out of 'obj'
    LOAD_GLOBAL     x        # push 'x' on the stack
    LOAD_GLOBAL     y        # push 'y' on the stack
    CALL_FUNCTION   2        # call the 'obj.meth' object with arguments x, y

We improved this by keeping method lookup separated from method call, unlike
some other approaches, but using the value stack as a cache instead of building
a temporary object.  We extended the bytecode compiler to (optionally) generate
the following code for ``obj.meth(x, y)``::

    LOAD_GLOBAL     obj
    LOOKUP_METHOD   meth
    LOAD_GLOBAL     x
    LOAD_GLOBAL     y
    CALL_METHOD     2

``LOOKUP_METHOD`` contains exactly the same attribute lookup logic as
``LOAD_ATTR`` - thus fully preserving semantics - but pushes two values onto the
stack instead of one.  These two values are an "inlined" version of the bound
method object: the *im_func* and *im_self*, i.e.  respectively the underlying
Python function object and a reference to ``obj``.  This is only possible when
the attribute actually refers to a function object from the class; when this is
not the case, ``LOOKUP_METHOD`` still pushes two values, but one *(im_func)* is
simply the regular result that ``LOAD_ATTR`` would have returned, and the other
*(im_self)* is an interpreter-level None placeholder.

After pushing the arguments, the layout of the stack in the above
example is as follows (the stack grows upwards):

+---------------------------------+
| ``y`` *(2nd arg)*               |
+---------------------------------+
| ``x`` *(1st arg)*               |
+---------------------------------+
| ``obj`` *(im_self)*             |
+---------------------------------+
| ``function object`` *(im_func)* |
+---------------------------------+

The ``CALL_METHOD N`` bytecode emulates a bound method call by
inspecting the *im_self* entry in the stack below the ``N`` arguments:
if it is not None, then it is considered to be an additional first
argument in the call to the *im_func* object from the stack.

.. more here?


Overall Effects
---------------

The impact these various optimizations have on performance unsurprisingly
depends on the program being run.  Using the default multi-dict implementation that
simply special cases string-keyed dictionaries is a clear win on all benchmarks,
improving results by anything from 15-40 per cent.

Another optimization, or rather set of optimizations, that has a uniformly good
effect are the two 'method optimizations', i.e. the
method cache and the LOOKUP_METHOD and CALL_METHOD opcodes.  On a heavily
object-oriented benchmark (richards) they combine to give a speed-up of nearly
50%, and even on the extremely un-object-oriented pystone benchmark, the
improvement is over 20%.

When building pypy, all generally useful optimizations are turned on by default
unless you explicitly lower the translation optimization level with the
``--opt`` option.
