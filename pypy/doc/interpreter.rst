Bytecode Interpreter
====================

.. contents::


Introduction and Overview
-------------------------

This document describes the implementation of PyPy's
Bytecode Interpreter and related Virtual Machine functionalities.

PyPy's bytecode interpreter has a structure reminiscent of CPython's
Virtual Machine: It processes code objects parsed and compiled from
Python source code.  It is implemented in the :source:`pypy/interpreter/` directory.
People familiar with the CPython implementation will easily recognize
similar concepts there.  The major differences are the overall usage of
the :doc:`object space <objspace>` indirection to perform operations on objects, and
the organization of the built-in modules (described :ref:`here <modules>`).

Code objects are a nicely preprocessed, structured representation of
source code, and their main content is *bytecode*.  We use the same
compact bytecode format as CPython 2.7, with minor differences in the bytecode
set.  Our bytecode compiler is
implemented as a chain of flexible passes (tokenizer, lexer, parser,
abstract syntax tree builder and bytecode generator).  The latter passes
are based on the ``compiler`` package from the standard library of
CPython, with various improvements and bug fixes. The bytecode compiler
(living under :source:`pypy/interpreter/astcompiler/`) is now integrated and is
translated with the rest of PyPy.

Code objects contain
condensed information about their respective functions, class and
module body source codes.  Interpreting such code objects means
instantiating and initializing a `Frame class`_ and then
calling its ``frame.eval()`` method.  This main entry point
initialize appropriate namespaces and then interprets each
bytecode instruction.  Python's standard library contains
the :source:`lib-python/2.7/dis.py` module which allows to inspection
of the virtual machine's bytecode instructions::

    >>> import dis
    >>> def f(x):
    ...     return x + 1
    >>> dis.dis(f)
    2         0 LOAD_FAST                0 (x)
              3 LOAD_CONST               1 (1)
              6 BINARY_ADD
              7 RETURN_VALUE

CPython and PyPy are stack-based virtual machines, i.e.
they don't have registers but instead push object to and pull objects
from a stack.  The bytecode interpreter is only responsible
for implementing control flow and pushing and pulling black
box objects to and from this value stack.  The bytecode interpreter
does not know how to perform operations on those black box
(:ref:`wrapped <wrapped>`) objects for which it delegates to the :doc:`object
space <objspace>`.  In order to implement a conditional branch in a program's
execution, however, it needs to gain minimal knowledge about a
wrapped object.  Thus, each object space has to offer a
``is_true(w_obj)`` operation which returns an
interpreter-level boolean value.

For the understanding of the interpreter's inner workings it
is crucial to recognize the concepts of :ref:`interpreter-level and
application-level <interpreter-level>` code.  In short, interpreter-level is executed
directly on the machine and invoking application-level functions
leads to an bytecode interpretation indirection. However,
special care must be taken regarding exceptions because
application level exceptions are wrapped into ``OperationErrors``
which are thus distinguished from plain interpreter-level exceptions.
See :ref:`application level exceptions <applevel-exceptions>` for some more information
on ``OperationErrors``.

The interpreter implementation offers mechanisms to allow a
caller to be unaware of whether a particular function invocation
leads to bytecode interpretation or is executed directly at
interpreter-level.  The two basic kinds of `Gateway classes`_
expose either an interpreter-level function to
application-level execution (``interp2app``) or allow
transparent invocation of application-level helpers
(``app2interp``) at interpreter-level.

Another task of the bytecode interpreter is to care for exposing its
basic code, frame, module and function objects to application-level
code.  Such runtime introspection and modification abilities are
implemented via `interpreter descriptors`_ (also see Raymond Hettingers
`how-to guide for descriptors`_ in Python, PyPy uses this model extensively).

A significant complexity lies in `function argument parsing`_.  Python as a
language offers flexible ways of providing and receiving arguments
for a particular function invocation.  Not only does it take special care
to get this right, it also presents difficulties for the :ref:`annotation
pass <rpython:annotator>` which performs a whole-program analysis on the
bytecode interpreter, argument parsing and gatewaying code
in order to infer the types of all values flowing across function
calls.

It is for this reason that PyPy resorts to generate
specialized frame classes and functions at :ref:`initialization
time <rpython:initialization-time>` in order to let the annotator only see rather static
program flows with homogeneous name-value assignments on
function invocations.

.. _how-to guide for descriptors: https://docs.python.org/3/howto/descriptor.html


Bytecode Interpreter Implementation Classes
-------------------------------------------

.. _Frame class:
.. _Frame:

Frame classes
~~~~~~~~~~~~~

The concept of Frames is pervasive in executing programs and
on virtual machines in particular. They are sometimes called
*execution frame* because they hold crucial information
regarding the execution of a Code_ object, which in turn is
often directly related to a Python `Function`_.  Frame
instances hold the following state:

- the local scope holding name-value bindings, usually implemented
  via a "fast scope" which is an array of wrapped objects

- a blockstack containing (nested) information regarding the
  control flow of a function (such as ``while`` and ``try`` constructs)

- a value stack where bytecode interpretation pulls object
  from and puts results on.  (``locals_stack_w`` is actually a single
  list containing both the local scope and the value stack.)

- a reference to the *globals* dictionary, containing
  module-level name-value bindings

- debugging information from which a current line-number and
  file location can be constructed for tracebacks

Moreover the Frame class itself has a number of methods which implement
the actual bytecodes found in a code object.  The methods of the ``PyFrame``
class are added in various files:

- the class ``PyFrame`` is defined in :source:`pypy/interpreter/pyframe.py`.

- the file :source:`pypy/interpreter/pyopcode.py` add support for all Python opcode.

.. _Code:

Code Class
~~~~~~~~~~

PyPy's code objects contain the same information found in CPython's code objects.
They differ from Function_ objects in that they are only immutable representations
of source code and don't contain execution state or references to the execution
environment found in `Frames`.  Frames and Functions have references
to a code object. Here is a list of Code attributes:

* ``co_flags`` flags if this code object has nested scopes/generators/etc.
* ``co_stacksize`` the maximum depth the stack can reach while executing the code
* ``co_code`` the actual bytecode string

* ``co_argcount`` number of arguments this code object expects
* ``co_varnames`` a tuple of all argument names pass to this code object
* ``co_nlocals`` number of local variables
* ``co_names`` a tuple of all names used in the code object
* ``co_consts`` a tuple of prebuilt constant objects ("literals") used in the code object
* ``co_cellvars`` a tuple of Cells containing values for access from nested scopes
* ``co_freevars`` a tuple of Cell names from "above" scopes

* ``co_filename`` source file this code object was compiled from
* ``co_firstlineno`` the first linenumber of the code object in its source file
* ``co_name`` name of the code object (often the function name)
* ``co_lnotab`` a helper table to compute the line-numbers corresponding to bytecodes


.. _Function:

Function and Method classes
~~~~~~~~~~~~~~~~~~~~~~~~~~~

The PyPy ``Function`` class (in :source:`pypy/interpreter/function.py`)
represents a Python function.  A ``Function`` carries the following
main attributes:

* ``func_doc`` the docstring (or None)
* ``func_name`` the name of the function
* ``func_code`` the Code_ object representing the function source code
* ``func_defaults`` default values for the function (built at function definition time)
* ``func_dict`` dictionary for additional (user-defined) function attributes
* ``func_globals`` reference to the globals dictionary
* ``func_closure`` a tuple of Cell references

``Functions`` classes also provide a ``__get__`` descriptor which creates a Method
object holding a binding to an instance or a class.  Finally, ``Functions``
and ``Methods`` both offer a ``call_args()`` method which executes
the function given an `Arguments`_ class instance.


.. _Arguments:

.. _function argument parsing:

Arguments Class
~~~~~~~~~~~~~~~

The Argument class (in :source:`pypy/interpreter/argument.py`) is
responsible for parsing arguments passed to functions.
Python has rather complex argument-passing concepts:

- positional arguments

- keyword arguments specified by name

- default values for positional arguments, defined at function
  definition time

- "star args" allowing a function to accept remaining
  positional arguments

- "star keyword args" allow a function to accept additional
  arbitrary name-value bindings

Moreover, a Function_ object can get bound to a class or instance
in which case the first argument to the underlying function becomes
the bound object.  The ``Arguments`` provides means to allow all
this argument parsing and also cares for error reporting.


.. _Module:

Module Class
~~~~~~~~~~~~

A ``Module`` instance represents execution state usually constructed
from executing the module's source file.  In addition to such a module's
global ``__dict__`` dictionary it has the following application level
attributes:

* ``__doc__`` the docstring of the module
* ``__file__`` the source filename from which this module was instantiated
* ``__path__`` state used for relative imports

Apart from the basic Module used for importing
application-level files there is a more refined
``MixedModule`` class (see :source:`pypy/interpreter/mixedmodule.py`)
which allows to define name-value bindings both at application
level and at interpreter level.  See the ``__builtin__``
module's :source:`pypy/module/__builtin__/__init__.py` file for an
example and the higher level :ref:`chapter on Modules in the coding
guide <modules>`.


Gateway classes
~~~~~~~~~~~~~~~

A unique PyPy property is the ability to easily cross the barrier
between interpreted and machine-level code (often referred to as
the difference between :ref:`interpreter-level and application-level <interpreter-level>`).
Be aware that the according code (in :source:`pypy/interpreter/gateway.py`)
for crossing the barrier in both directions is somewhat
involved, mostly due to the fact that the type-inferring
annotator needs to keep track of the types of objects flowing
across those barriers.


Making interpreter-level functions available at application-level
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

In order to make an interpreter-level function available at
application level, one invokes ``pypy.interpreter.gateway.interp2app(func)``.
Such a function usually takes a ``space`` argument and any number
of positional arguments. Additionally, such functions can define
an ``unwrap_spec`` telling the ``interp2app`` logic how
application-level provided arguments should be unwrapped
before the actual interpreter-level function is invoked.
For example, `interpreter descriptors`_ such as the ``Module.__new__``
method for allocating and constructing a Module instance are
defined with such code::

    Module.typedef = TypeDef("module",
        __new__ = interp2app(Module.descr_module__new__.im_func,
                             unwrap_spec=[ObjSpace, W_Root, Arguments]),
        __init__ = interp2app(Module.descr_module__init__),
                        # module dictionaries are readonly attributes
        __dict__ = GetSetProperty(descr_get_dict, cls=Module),
        __doc__ = 'module(name[, doc])\n\nCreate a module object...'
        )

The actual ``Module.descr_module__new__`` interpreter-level method
referenced from the ``__new__`` keyword argument above is defined
like this::

    def descr_module__new__(space, w_subtype, __args__):
        module = space.allocate_instance(Module, w_subtype)
        Module.__init__(module, space, None)
        return space.wrap(module)

Summarizing, the ``interp2app`` mechanism takes care to route
an application level access or call to an internal interpreter-level
object appropriately to the descriptor, providing enough precision
and hints to keep the type-inferring annotator happy.


Calling into application level code from interpreter-level
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Application level code is :ref:`often preferable <app-preferable>`. Therefore,
we often like to invoke application level code from interpreter-level.
This is done via the Gateway's ``app2interp`` mechanism
which we usually invoke at definition time in a module.
It generates a hook which looks like an interpreter-level
function accepting a space and an arbitrary number of arguments.
When calling a function at interpreter-level the caller side
does usually not need to be aware if its invoked function
is run through the PyPy interpreter or if it will directly
execute on the machine (after translation).

Here is an example showing how we implement the Metaclass
finding algorithm of the Python language in PyPy::

    app = gateway.applevel(r'''
        def find_metaclass(bases, namespace, globals, builtin):
            if '__metaclass__' in namespace:
                return namespace['__metaclass__']
            elif len(bases) > 0:
                base = bases[0]
                if hasattr(base, '__class__'):
                        return base.__class__
                else:
                        return type(base)
            elif '__metaclass__' in globals:
                return globals['__metaclass__']
            else:
                try:
                    return builtin.__metaclass__
                except AttributeError:
                    return type
    ''', filename=__file__)

    find_metaclass  = app.interphook('find_metaclass')

The ``find_metaclass`` interpreter-level hook is invoked
with five arguments from the ``BUILD_CLASS`` opcode implementation
in :source:`pypy/interpreter/pyopcode.py`::

    def BUILD_CLASS(f):
        w_methodsdict = f.valuestack.pop()
        w_bases       = f.valuestack.pop()
        w_name        = f.valuestack.pop()
        w_metaclass = find_metaclass(f.space, w_bases,
                                     w_methodsdict, f.w_globals,
                                     f.space.wrap(f.builtin))
        w_newclass = f.space.call_function(w_metaclass, w_name,
                                           w_bases, w_methodsdict)
        f.valuestack.push(w_newclass)

Note that at a later point we can rewrite the ``find_metaclass``
implementation at interpreter-level and we would not have
to modify the calling side at all.


.. _interpreter descriptors:

Introspection and Descriptors
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Python traditionally has a very far-reaching introspection model
for bytecode interpreter related objects. In PyPy and in CPython read
and write accesses to such objects are routed to descriptors.
Of course, in CPython those are implemented in ``C`` while in
PyPy they are implemented in interpreter-level Python code.

All instances of a Function_, Code_, Frame_ or Module_ classes
are also ``W_Root`` instances which means they can be represented
at application level.  These days, a PyPy object space needs to
work with a basic descriptor lookup when it encounters
accesses to an interpreter-level object:  an object space asks
a wrapped object for its type via a ``getclass`` method and then
calls the type's ``lookup(name)`` function in order to receive a descriptor
function.  Most of PyPy's internal object descriptors are defined at the
end of :source:`pypy/interpreter/typedef.py`.  You can use these definitions
as a reference for the exact attributes of interpreter classes visible
at application level.
