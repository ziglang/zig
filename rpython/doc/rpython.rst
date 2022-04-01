.. _language:

RPython Language
================

Definition
----------

RPython is a restricted subset of Python that is amenable to static analysis.
Although there are additions to the language and some things might surprisingly
work, this is a rough list of restrictions that should be considered. Note
that there are tons of special cased restrictions that you'll encounter
as you go. The exact definition is "RPython is everything that our translation
toolchain can accept" :)


Flow restrictions
-----------------

**variables**

  variables should contain values of at most one type as described in
  `Object restrictions`_ at each control flow point, that means for
  example that joining control paths using the same variable to
  contain both a string and a int must be avoided.  It is allowed to
  mix None (basically with the role of a null pointer) with many other
  types: wrapped objects, class instances, lists, dicts, strings, etc.
  but *not* with int, floats or tuples.

**constants**

  all module globals are considered constants.  Their binding must not
  be changed at run-time.  Moreover, global (i.e. prebuilt) lists and
  dictionaries are supposed to be immutable: modifying e.g. a global
  list will give inconsistent results.  However, global instances don't
  have this restriction, so if you need mutable global state, store it
  in the attributes of some prebuilt singleton instance.

**control structures**

  all allowed, ``for`` loops restricted to builtin types, generators
  very restricted.

**range**

  ``range`` and ``xrange`` are identical. ``range`` does not necessarily create an array,
  only if the result is modified. It is allowed everywhere and completely
  implemented. The only visible difference to CPython is the inaccessibility
  of the ``xrange`` fields start, stop and step.

**definitions**

  run-time definition of classes or functions is not allowed.

**generators**

  generators are supported, but their exact scope is very limited. you can't
  merge two different generator in one control point.

**exceptions**

  fully supported.
  see below `Exception rules`_ for restrictions on exceptions raised by built-in operations


Object restrictions
-------------------

We are using

**integer, float, boolean**

  works.

**strings**

  a lot of, but not all string methods are supported and those that are
  supported, not necesarilly accept all arguments.  Indexes can be
  negative.  In case they are not, then you get slightly more efficient
  code if the translator can prove that they are non-negative.  When
  slicing a string it is necessary to prove that the slice start and
  stop indexes are non-negative. There is no implicit str-to-unicode cast
  anywhere. Simple string formatting using the ``%`` operator works, as long
  as the format string is known at translation time; the only supported
  formatting specifiers are ``%s``, ``%d``, ``%x``, ``%o``, ``%f``, plus
  ``%r`` but only for user-defined instances. Modifiers such as conversion
  flags, precision, length etc. are not supported. Moreover, it is forbidden
  to mix unicode and strings when formatting.

**tuples**

  no variable-length tuples; use them to store or return pairs or n-tuples of
  values. Each combination of types for elements and length constitute
  a separate and not mixable type.
  
  There is no general way to convert a list into a tuple, because the
  length of the result would not be known statically.  (You can of course
  do ``t = (lst[0], lst[1], lst[2])`` if you know that ``lst`` has got 3
  items.)

**lists**

  lists are used as an allocated array.  Lists are over-allocated, so list.append()
  is reasonably fast. However, if you use a fixed-size list, the code
  is more efficient. Annotator can figure out most of the time that your
  list is fixed-size, even when you use list comprehension.
  Negative or out-of-bound indexes are only allowed for the
  most common operations, as follows:

  - *indexing*:
    positive and negative indexes are allowed. Indexes are checked when requested
    by an IndexError exception clause.

  - *slicing*:
    the slice start must be within bounds. The stop doesn't need to, but it must
    not be smaller than the start.  All negative indexes are disallowed, except for
    the [:-1] special case.  No step.  Slice deletion follows the same rules.

  - *slice assignment*:
    only supports ``lst[x:y] = sublist``, if ``len(sublist) == y - x``.
    In other words, slice assignment cannot change the total length of the list,
    but just replace items.

  - *other operators*:
    ``+``, ``+=``, ``in``, ``*``, ``*=``, ``==``, ``!=`` work as expected.

  - *methods*:
    append, index, insert, extend, reverse, pop.  The index used in pop() follows
    the same rules as for *indexing* above.  The index used in insert() must be within
    bounds and not negative.

**dicts**

  dicts with a unique key type only, provided it is hashable. Custom
  hash functions and custom equality will not be honored.
  Use ``rpython.rlib.objectmodel.r_dict`` for custom hash functions.

**sets**

  sets are not directly supported in RPython. Instead you should use a
  plain dict and fill the values with None. Values in that dict
  will not consume space.

**list comprehensions**

  May be used to create allocated, initialized arrays.

**functions**

+ function declarations may use defaults and ``*args``, but not
  ``**keywords``.

+ function calls may be done to a known function or to a variable one,
  or to a method.  You can call with positional and keyword arguments,
  and you can pass a ``*args`` argument (it must be a tuple).

+ as explained above, tuples are not of a variable length.  If you need
  to call a function with a dynamic number of arguments, refactor the
  function itself to accept a single argument which is a regular list.

+ dynamic dispatch enforces the use of signatures that are equal for all
  possible called function, or at least "compatible enough".  This
  concerns mainly method calls, when the method is overridden or in any
  way given different definitions in different classes.  It also concerns
  the less common case of explicitly manipulated function objects.
  Describing the exact compatibility rules is rather involved (but if you
  break them, you should get explicit errors from the rtyper and not
  obscure crashes.)

**builtin functions**

  A number of builtin functions can be used.  The precise set can be
  found in :source:`rpython/annotator/builtin.py` (see ``def builtin_xxx()``).
  Some builtin functions may be limited in what they support, though.

  ``int, float, str, ord, chr``... are available as simple conversion
  functions.  Note that ``int, float, str``... have a special meaning as
  a type inside of isinstance only.

**classes**

+ methods and other class attributes do not change after startup
+ single inheritance is fully supported
+ use `rpython.rlib.objectmodel.import_from_mixin(M)` in a class
  body to copy the whole content of a class `M`.  This can be used
  to implement mixins: functions and staticmethods are duplicated
  (the other class attributes are just copied unmodified).

+ classes are first-class objects too

**objects**

  Normal rules apply. The only special methods that are honoured are
  ``__init__``, ``__del__``, ``__len__``, ``__getitem__``, ``__setitem__``,
  ``__getslice__``, ``__setslice__``, and ``__iter__``. To handle slicing,
  ``__getslice__`` and ``__setslice__`` must be used; using ``__getitem__`` and
  ``__setitem__`` for slicing isn't supported. Additionally, using negative
  indices for slicing is still not support, even when using ``__getslice__``.

  Note that the destructor ``__del__`` should only contain `simple
  operations`__; for any kind of more complex destructor, consider
  using instead ``rpython.rlib.rgc.FinalizerQueue``.

.. __: garbage_collection.html

This layout makes the number of types to take care about quite limited.


Integer Types
-------------

While implementing the integer type, we stumbled over the problem that
integers are quite in flux in CPython right now. Starting with Python 2.4,
integers mutate into longs on overflow.  In contrast, we need
a way to perform wrap-around machine-sized arithmetic by default, while still
being able to check for overflow when we need it explicitly.  Moreover, we need
a consistent behavior before and after translation.

We use normal integers for signed arithmetic.  It means that before
translation we get longs in case of overflow, and after translation we get a
silent wrap-around.  Whenever we need more control, we use the following
helpers (which live in :source:`rpython/rlib/rarithmetic.py`):

**ovfcheck()**

  This special function should only be used with a single arithmetic operation
  as its argument, e.g. ``z = ovfcheck(x+y)``.  Its intended meaning is to
  perform the given operation in overflow-checking mode.

  At run-time, in Python, the ovfcheck() function itself checks the result
  and raises OverflowError if it is a ``long``.  But the code generators use
  ovfcheck() as a hint: they replace the whole ``ovfcheck(x+y)`` expression
  with a single overflow-checking addition in C.

**intmask()**

  This function is used for wrap-around arithmetic.  It returns the lower bits
  of its argument, masking away anything that doesn't fit in a C "signed long int".
  Its purpose is, in Python, to convert from a Python ``long`` that resulted from a
  previous operation back to a Python ``int``.  The code generators ignore
  intmask() entirely, as they are doing wrap-around signed arithmetic all the time
  by default anyway.  (We have no equivalent of the "int" versus "long int"
  distinction of C at the moment and assume "long ints" everywhere.)

**r_uint**

  In a few cases (e.g. hash table manipulation), we need machine-sized unsigned
  arithmetic.  For these cases there is the r_uint class, which is a pure
  Python implementation of word-sized unsigned integers that silently wrap
  around.  ("word-sized" and "machine-sized" are used equivalently and mean
  the native size, which you get using "unsigned long" in C.)
  The purpose of this class (as opposed to helper functions as above)
  is consistent typing: both Python and the annotator will propagate r_uint
  instances in the program and interpret all the operations between them as
  unsigned.  Instances of r_uint are special-cased by the code generators to
  use the appropriate low-level type and operations.
  Mixing of (signed) integers and r_uint in operations produces r_uint that
  means unsigned results.  To convert back from r_uint to signed integers, use
  intmask().


Type Enforcing and Checking
---------------------------

RPython provides a helper decorator to force RPython-level types on function
arguments. The decorator, called ``enforceargs()``, accepts as parameters the
types expected to match the arguments of the function.

Functions decorated with ``enforceargs()`` have their function signature
analyzed and their RPython-level type inferred at import time (for further
details about the flavor of translation performed in RPython, see the
`Annotation pass documentation`_). Encountering types not supported by RPython
will raise a ``TypeError``.

``enforceargs()`` by default also performs type checking of parameter types
each time the function is invoked. To disable this behavior, it's possible to
pass the ``typecheck=False`` parameter to the decorator.

.. _Annotation pass documentation: http://rpython.readthedocs.io/en/latest/translation.html#annotator


Exception rules
---------------

Exceptions are by default not generated for simple cases.::

    #!/usr/bin/python

        lst = [1,2,3,4,5]
        item = lst[i]    # this code is not checked for out-of-bound access

        try:
            item = lst[i]
        except IndexError:
            # complain

Code with no exception handlers does not raise exceptions (after it has been
translated, that is.  When you run it on top of CPython, it may raise
exceptions, of course). By supplying an exception handler, you ask for error
checking. Without, you assure the system that the operation cannot fail.
This rule does not apply to *function calls*: any called function is
assumed to be allowed to raise any exception.

For example::

    x = 5.1
    x = x + 1.2       # not checked for float overflow
    try:
        x = x + 1.2
    except OverflowError:
        # float result too big

But::

    z = some_function(x, y)    # can raise any exception
    try:
        z = some_other_function(x, y)
    except IndexError:
        # only catches explicitly-raised IndexErrors in some_other_function()
        # other exceptions can be raised, too, and will not be caught here.

The ovfcheck() function described above follows the same rule: in case of
overflow, it explicitly raise OverflowError, which can be caught anywhere.

Exceptions explicitly raised or re-raised will always be generated.


PyPy is debuggable on top of CPython
------------------------------------

PyPy has the advantage that it is runnable on standard
CPython.  That means, we can run all of PyPy with all exception
handling enabled, so we might catch cases where we failed to
adhere to our implicit assertions.
