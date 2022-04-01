The Object Space
================

.. contents::


.. _objectspace:
.. _Object Space:

Introduction
------------

The object space creates all objects in PyPy, and knows how to perform operations
on them. It may be helpful to think of an object space as being a library
offering a fixed API: a set of *operations*, along with implementations that
correspond to the known semantics of Python objects.

For example, :py:func:`add` is an operation, with implementations in the object
space that perform numeric addition (when :py:func:`add` is operating on numbers),
concatenation (when :py:func:`add` is operating on sequences), and so on.

We have some working object spaces which can be plugged into
the bytecode interpreter:

- The *Standard Object Space* is a complete implementation
  of the various built-in types and objects of Python.  The Standard Object
  Space, together with the bytecode interpreter, is the foundation of our Python
  implementation.  Internally, it is a set of :ref:`interpreter-level <interpreter-level>` classes
  implementing the various :ref:`application-level <application-level>` objects -- integers, strings,
  lists, types, etc.  To draw a comparison with CPython, the Standard Object
  Space provides the equivalent of the C structures :c:type:`PyIntObject`,
  :c:type:`PyListObject`, etc.

- various `Object Space proxies`_ wrap another object space (e.g. the standard
  one) and adds new capabilities, like lazily computed objects (computed only
  when an operation is performed on them), security-checking objects,
  distributed objects living on several machines, etc.

The various object spaces documented here can be found in :source:`pypy/objspace`.

Note that most object-space operations take and return
:ref:`application-level <application-level>` objects, which are treated as
opaque "black boxes" by the interpreter. Only a very few operations allow the
bytecode interpreter to gain some knowledge about the value of an
application-level object.

.. _objspace-interface:

Object Space Interface
----------------------

This is the public API that all Object Spaces implement:


Administrative Functions
~~~~~~~~~~~~~~~~~~~~~~~~

.. py:function:: getexecutioncontext()

   Return the currently active execution context.
   (:source:`pypy/interpreter/executioncontext.py`).

.. py:function:: getbuiltinmodule(name)

   Return a :py:class:`Module` object for the built-in module given by ``name``.
   (:source:`pypy/interpreter/module.py`).


Operations on Objects in the Object Space
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These functions both take and return "wrapped" (i.e. :ref:`application-level <application-level>`) objects.

The following functions implement operations with straightforward semantics that
directly correspond to language-level constructs:

   ``id, type, issubtype, iter, next, repr, str, len, hash,``

   ``getattr, setattr, delattr, getitem, setitem, delitem,``

   ``pos, neg, abs, invert, add, sub, mul, truediv, floordiv, div, mod, divmod, pow, lshift, rshift, and_, or_, xor,``

   ``nonzero, hex, oct, int, float, long, ord,``

   ``lt, le, eq, ne, gt, ge, cmp, coerce, contains,``

   ``inplace_add, inplace_sub, inplace_mul, inplace_truediv, inplace_floordiv,
   inplace_div, inplace_mod, inplace_pow, inplace_lshift, inplace_rshift,
   inplace_and, inplace_or, inplace_xor,``

   ``get, set, delete, userdel``

.. py:function:: call(w_callable, w_args, w_kwds)

   Calls a function with the given positional (``w_args``) and keyword (``w_kwds``)
   arguments.

.. py:function:: index(w_obj)

   Implements index lookup (`as introduced in CPython 2.5`_) using ``w_obj``. Will return a
   wrapped integer or long, or raise a :py:exc:`TypeError` if the object doesn't have an
   :py:func:`__index__` special method.

.. _as introduced in CPython 2.5: https://www.python.org/dev/peps/pep-0357/

.. py:function:: is_(w_x, w_y)

   Implements ``w_x is w_y``.

.. py:function:: isinstance(w_obj, w_type)

   Implements :py:func:`issubtype` with ``type(w_obj)`` and ``w_type`` as arguments.

.. py:function::exception_match(w_exc_type, w_check_class)

   Checks if the given exception type matches :py:obj:`w_check_class`. Used in
   matching the actual exception raised with the list of those to catch in an
   except clause.


Convenience Functions
~~~~~~~~~~~~~~~~~~~~~

The following functions are used so often that it was worthwhile to introduce
them as shortcuts -- however, they are not strictly necessary since they can be
expressed using several other object space methods.

.. py:function:: eq_w(w_obj1, w_obj2)

   Returns :py:const:`True` when :py:obj:`w_obj1` and :py:obj:`w_obj2` are equal.
   Shortcut for ``space.is_true(space.eq(w_obj1, w_obj2))``.

.. py:function:: is_w(w_obj1, w_obj2)

   Shortcut for ``space.is_true(space.is_(w_obj1, w_obj2))``.

.. py:function:: hash_w(w_obj)

   Shortcut for ``space.int_w(space.hash(w_obj))``.

.. py:function:: len_w(w_obj)

   Shortcut for ``space.int_w(space.len(w_obj))``.

*NOTE* that the above four functions return :ref:`interpreter-level <interpreter-level>`
objects, not :ref:`application-level <application-level>` ones!

.. py:function:: not_(w_obj)

   Shortcut for ``space.newbool(not space.is_true(w_obj))``.

.. py:function:: finditem(w_obj, w_key)

   Equivalent to ``getitem(w_obj, w_key)`` but returns an **interpreter-level** None
   instead of raising a KeyError if the key is not found.

.. py:function:: call_function(w_callable, *args_w, **kw_w)

   Collects the arguments in a wrapped tuple and dict and invokes
   ``space.call(w_callable, ...)``.

.. py:function:: call_method(w_object, 'method', ...)

   Uses :py:meth:`space.getattr` to get the method object, and then :py:meth:`space.call_function`
   to invoke it.

.. py:function:: unpackiterable(w_iterable[, expected_length=-1])

   Iterates over :py:obj:`w_x` (using :py:meth:`space.iter` and :py:meth:`space.next`)
   and collects the resulting wrapped objects in a list. If ``expected_length`` is
   given and the length does not match, raises an exception.

   Of course, in cases where iterating directly is better than collecting the
   elements in a list first, you should use :py:meth:`space.iter` and :py:meth:`space.next`
   directly.

.. py:function:: unpacktuple(w_tuple[, expected_length=None])

   Equivalent to :py:func:`unpackiterable`, but only for tuples.

.. py:function:: callable(w_obj)

   Implements the built-in :py:func:`callable`.


Creation of Application Level objects
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. py:function:: wrap(x)

   **Deprecated! Eventually this method should disappear.**
   Returns a wrapped object that is a reference to the interpreter-level object
   :py:obj:`x`. This can be used either on simple immutable objects (integers,
   strings, etc) to create a new wrapped object, or on instances of :py:class:`W_Root`
   to obtain an application-level-visible reference to them.  For example,
   most classes of the bytecode interpreter subclass :py:class:`W_Root` and can
   be directly exposed to application-level code in this way - functions, frames,
   code objects, etc.

.. py:function:: newint(i)

   Creates a wrapped object holding an integral value. `newint` creates an object
   of type `W_IntObject`.

.. py:function:: newlong(l)

   Creates a wrapped object holding an integral value. The main difference to newint
   is the type of the argument (which is rpython.rlib.rbigint.rbigint). On PyPy3 this
   method will return an :py:class:`int` (PyPy2 it returns a :py:class:`long`).

.. py:function:: newbytes(t)

   The given argument is a rpython bytestring. Creates a wrapped object
   of type :py:class:`bytes` (both on PyPy2 and PyPy3).

.. py:function:: newtext(t)

   The given argument is a rpython bytestring. Creates a wrapped object
   of type :py:class:`str`.  On PyPy3 this will return a wrapped unicode
   object. The object will hold a utf-8-nosg decoded value of `t`.
   The "utf-8-nosg" codec used here is slightly different from the
   "utf-8" implemented in Python 2 or Python 3: it is defined as utf-8
   without any special handling of surrogate characters.  They are
   encoded using the same three-bytes sequence that encodes any char in
   the range from ``'\u0800'`` to ``'\uffff'``.

   PyPy2 will return a bytestring object. No encoding/decoding steps will be applied.

.. py:function:: newbool(b)

   Creates a wrapped :py:class:`bool` object from an :ref:`interpreter-level <interpreter-level>`
   object.

.. py:function:: newtuple([w_x, w_y, w_z, ...])

   Creates a new wrapped tuple out of an interpreter-level list of wrapped objects.

.. py:function:: newlist([..])

   Creates a wrapped :py:class:`list` from an interpreter-level list of wrapped objects.

.. py:function:: newdict

   Returns a new empty dictionary.

.. py:function:: newslice(w_start, w_end, w_step)

   Creates a new slice object.

.. py:function:: newunicode(ustr)

   Creates a Unicode string from an rpython unicode string.
   This method may disappear soon and be replaced by :py:function::`newutf8`.

.. py:function:: newutf8(bytestr)

   Creates a Unicode string from an rpython byte string, decoded as
   "utf-8-nosg".  On PyPy3 it is the same as :py:function::`newtext`.

Many more space operations can be found in `pypy/interpeter/baseobjspace.py` and
`pypy/objspace/std/objspace.py`.

Conversions from Application Level to Interpreter Level
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. py:function:: unwrap(w_x)

   Returns the interpreter-level equivalent of :py:obj:`w_x` -- use this
   **ONLY** for testing, because this method is not RPython and thus cannot be
   translated! In most circumstances you should use the functions described
   below instead.

.. py:function:: is_true(w_x)

   Returns a interpreter-level boolean (:py:const:`True` or :py:const:`False`) that
   gives the truth value of the wrapped object :py:obj:`w_x`.

   This is a particularly important operation because it is necessary to implement,
   for example, if-statements in the language (or rather, to be pedantic, to
   implement the conditional-branching bytecodes into which if-statements are
   compiled).

.. py:function:: int_w(w_x)

   If :py:obj:`w_x` is an application-level integer or long which can be converted
   without overflow to an integer, return an interpreter-level integer. Otherwise
   raise :py:exc:`TypeError` or :py:exc:`OverflowError`.

.. py:function:: bigint_w(w_x)

   If :py:obj:`w_x` is an application-level integer or long, return an interpreter-level
   :py:class:`rbigint`. Otherwise raise :py:exc:`TypeError`.

.. automethod:: pypy.interpreter.baseobjspace.ObjSpace.bytes_w(w_x)
.. automethod:: pypy.interpreter.baseobjspace.ObjSpace.text_w(w_x)

.. py:function:: str_w(w_x)

   **Deprecated. use text_w or bytes_w instead**
   If :py:obj:`w_x` is an application-level string, return an interpreter-level string.
   Otherwise raise :py:exc:`TypeError`.

.. py:function:: unicode_w(w_x)

   Takes an application level :py:class::`unicode` and return an
   interpreter-level unicode string.  This method may disappear soon and
   be replaced by :py:function::`text_w`.

.. py:function:: float_w(w_x)

   If :py:obj:`w_x` is an application-level float, integer or long, return an
   interpreter-level float. Otherwise raise :py:exc:`TypeError` (or:py:exc:`OverflowError`
   in the case of very large longs).

.. py:function:: getindex_w(w_obj[, w_exception=None])

   Call ``index(w_obj)``. If the resulting integer or long object can be converted
   to an interpreter-level :py:class:`int`, return that. If not, return a clamped
   result if :py:obj:`w_exception` is None, otherwise raise the exception at the
   application level.

   (If :py:obj:`w_obj` can't be converted to an index, :py:func:`index` will raise an
   application-level :py:exc:`TypeError`.)

.. py:function:: interp_w(RequiredClass, w_x[, can_be_None=False])

   If :py:obj:`w_x` is a wrapped instance of the given bytecode interpreter class,
   unwrap it and return it.  If :py:obj:`can_be_None` is :py:const:`True`, a wrapped
   :py:const:`None` is also accepted and returns an interpreter-level :py:const:`None`.
   Otherwise, raises an :py:exc:`OperationError` encapsulating a :py:exc:`TypeError`
   with a nice error message.

.. py:function:: interpclass_w(w_x)

   If :py:obj:`w_x` is a wrapped instance of an bytecode interpreter class -- for
   example :py:class:`Function`, :py:class:`Frame`, :py:class:`Cell`, etc. -- return
   it unwrapped.  Otherwise return :py:const:`None`.


Data Members
~~~~~~~~~~~~

.. py:data:: space.builtin

   The :py:class:`Module` containing the builtins.

.. py:data:: space.sys

   The ``sys`` :py:class:`Module`.

.. py:data:: space.w_None

   The ObjSpace's instance of :py:const:`None`.

.. py:data:: space.w_True

   The ObjSpace's instance of :py:const:`True`.

.. py:data:: space.w_False

   The ObjSpace's instance of :py:const:`False`.

.. py:data:: space.w_Ellipsis

   The ObjSpace's instance of :py:const:`Ellipsis`.

.. py:data:: space.w_NotImplemented

   The ObjSpace's instance of :py:const:`NotImplemented`.

.. py:data:: space.w_int
             space.w_float
             space.w_long
             space.w_tuple
             space.w_str
             space.w_unicode
             space.w_type
             space.w_instance
             space.w_slice

   Python's most common basic type objects.

.. py:data:: space.w_[XYZ]Error

   Python's built-in exception classes (:py:class:`KeyError`, :py:class:`IndexError`,
   etc).

.. TODO: is it worth listing out all ~50 builtin exception types (https://docs.python.org/2/library/exceptions.html)?

.. py:data:: ObjSpace.MethodTable

   List of tuples containing ``(method_name, symbol, number_of_arguments, list_of_special_names)``
   for the regular part of the interface.

   *NOTE* that tuples are interpreter-level.

.. py:data:: ObjSpace.BuiltinModuleTable

   List of names of built-in modules.

.. py:data:: ObjSpace.ConstantTable

   List of names of the constants that the object space should define.

.. py:data:: ObjSpace.ExceptionTable

   List of names of exception classes.

.. py:data:: ObjSpace.IrregularOpTable

   List of names of methods that have an irregular API (take and/or return
   non-wrapped objects).


.. _standard-object-space:

The Standard Object Space
-------------------------

Introduction
~~~~~~~~~~~~

The Standard Object Space (:source:`pypy/objspace/std/`) is the direct equivalent
of CPython's object library (the ``Objects/`` subdirectory in the distribution).
It is an implementation of the common Python types in a lower-level language.

The Standard Object Space defines an abstract parent class, :py:class:`W_Object`
as well as subclasses like :py:class:`W_IntObject`, :py:class:`W_ListObject`,
and so on. A wrapped object (a "black box" for the bytecode interpreter's main
loop) is an instance of one of these classes. When the main loop invokes an
operation (such as addition), between two wrapped objects :py:obj:`w1` and
:py:obj:`w2`, the Standard Object Space does some internal dispatching (similar
to ``Object/abstract.c`` in CPython) and invokes a method of the proper
:py:class:`W_XYZObject` class that can perform the operation.

The operation itself is done with the primitives allowed by RPython, and the
result is constructed as a wrapped object. For example, compare the following
implementation of integer addition with the function :c:func:`int_add()` in
``Object/intobject.c``: ::

    def add__Int_Int(space, w_int1, w_int2):
        x = w_int1.intval
        y = w_int2.intval
        try:
            z = ovfcheck(x + y)
        except OverflowError:
            raise FailedToImplementArgs(space.w_OverflowError,
                                    space.wrap("integer addition"))
        return W_IntObject(space, z)

This may seem like a lot of work just for integer objects (why wrap them into
:py:class:`W_IntObject` instances instead of using plain integers?), but the
code is kept simple and readable by wrapping all objects (from simple integers
to more complex types) in the same way.

(Interestingly, the obvious optimization above has actually been made in PyPy,
but isn't hard-coded at this level -- see :doc:`interpreter-optimizations`.)


Object types
~~~~~~~~~~~~

The larger part of the :source:`pypy/objspace/std/` package defines and
implements the library of Python's standard built-in object types.  Each type
``xxx`` (:py:class:`int`, :py:class:`float`, :py:class:`list`,
:py:class:`tuple`, :py:class:`str`, :py:class:`type`, etc.) is typically
implemented in the module ``xxxobject.py``.

The ``W_AbstractXxxObject`` class, when present, is the abstract base
class, which mainly defines what appears on the Python-level type
object.  There are then actual implementations as subclasses, which are
called ``W_XxxObject`` or some variant for the cases where we have
several different implementations.  For example,
:source:`pypy/objspace/std/bytesobject.py` defines ``W_AbstractBytesObject``,
which contains everything needed to build the ``str`` app-level type;
and there are subclasses ``W_BytesObject`` (the usual string) and
``W_Buffer`` (a special implementation tweaked for repeated
additions, in :source:`pypy/objspace/std/bufferobject.py`).  For mutable data
types like lists and dictionaries, we have a single class
``W_ListObject`` or ``W_DictMultiObject`` which has an indirection to
the real data and a strategy; the strategy can change as the content of
the object changes.

From the user's point of view, even when there are several
``W_AbstractXxxObject`` subclasses, this is not visible: at the
app-level, they are still all instances of exactly the same Python type.
PyPy knows that (e.g.) the application-level type of its
interpreter-level ``W_BytesObject`` instances is str because there is a
``typedef`` class attribute in ``W_BytesObject`` which points back to
the string type specification from :source:`pypy/objspace/std/bytesobject.py`;
all other implementations of strings use the same ``typedef`` from
:source:`pypy/objspace/std/bytesobject.py`.

For other examples of multiple implementations of the same Python type,
see :doc:`interpreter-optimizations`.


Object Space proxies
--------------------

We have implemented several *proxy object spaces*, which wrap another object
space (typically the standard one) and add some capabilities to all objects. To
find out more, see :doc:`objspace-proxies`.
