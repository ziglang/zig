Goals and Architecture Overview
===============================

.. contents::

This document gives an overview of the goals and architecture of PyPy. If you're
interested in :ref:`using PyPy <using-pypy>` or hacking on it,
have a look at our :ref:`getting started <getting-started-index>` section.


Mission statement
-----------------

We aim to provide a compliant, flexible and fast implementation of the Python_
Language which uses the RPython toolchain to enable new advanced high-level
features without having to encode the low-level details.  We call this PyPy.

.. _Python: https://docs.python.org/3/reference/


High Level Goals
----------------

Our main motivation for developing the translation framework is to
provide a full featured, customizable, :ref:`fast <how-fast-is-pypy>` and
:doc:`very compliant <cpython_differences>` Python
implementation, working on and interacting with a large variety of
platforms and allowing the quick introduction of new advanced language
features.

This Python implementation is written in RPython as a relatively simple
interpreter, in some respects easier to understand than CPython, the C
reference implementation of Python.  We are using its high level and
flexibility to quickly experiment with features or implementation
techniques in ways that would, in a traditional approach, require
pervasive changes to the source code.  For example, PyPy's Python
interpreter can optionally provide lazily computed objects - a small
extension that would require global changes in CPython.  Another example
is the garbage collection technique: changing CPython to use a garbage
collector not based on reference counting would be a major undertaking,
whereas in PyPy it is an issue localized in the translation framework,
and fully orthogonal to the interpreter source code.


.. _python-interpreter:

PyPy Python Interpreter
-----------------------

PyPy's *Python Interpreter* is written in RPython and implements the
full Python language.  This interpreter very closely emulates the
behavior of CPython.  It contains the following key components:

- a bytecode compiler responsible for producing Python code objects
  from the source code of a user application;

- a :doc:`bytecode evaluator <interpreter>` responsible for interpreting
  Python code objects;

- a :ref:`standard object space <standard-object-space>`, responsible for creating and manipulating
  the Python objects seen by the application.

The *bytecode compiler* is the preprocessing phase that produces a
compact bytecode format via a chain of flexible passes (tokenizer,
lexer, parser, abstract syntax tree builder, bytecode generator).  The
*bytecode evaluator* interprets this bytecode.  It does most of its work
by delegating all actual manipulations of user objects to the *object
space*.  The latter can be thought of as the library of built-in types.
It defines the implementation of the user objects, like integers and
lists, as well as the operations between them, like addition or
truth-value-testing.

This division between bytecode evaluator and object space gives a lot of
flexibility.  One can plug in different :doc:`object spaces <objspace>` to get
different or enriched behaviours of the Python objects.

Layers
------

RPython
~~~~~~~
:ref:`RPython <rpython:language>` is the language in which we write interpreters.
Not the entire PyPy project is written in RPython, only the parts that are
compiled in the translation process. The interesting point is that RPython
has no parser, it's compiled from the live python objects, which makes it
possible to do all kinds of metaprogramming during import time. In short,
Python is a meta programming language for RPython.

The RPython standard library is to be found in the ``rlib`` subdirectory.

Consult `Getting Started with RPython`_ for further reading or `RPython By
Example`_ for another take on what can be done using RPython without writing an
interpreter over it.

Translation
~~~~~~~~~~~
The translation toolchain - this is the part that takes care of translating
RPython to flow graphs and then to C. There is more in the
:doc:`architecture <architecture>` document written about it.

It lives in the ``rpython`` directory: ``flowspace``, ``annotator``
and ``rtyper``.

PyPy Interpreter
~~~~~~~~~~~~~~~~
This is in the ``pypy`` directory.  ``pypy/interpreter`` is a standard
interpreter for Python written in RPython.  The fact that it is
RPython is not apparent at first.  Built-in modules are written in
``pypy/module/*``.  Some modules that CPython implements in C are
simply written in pure Python; they are in the top-level ``lib_pypy``
directory.  The standard library of Python (with a few changes to
accomodate PyPy) is in ``lib-python``.

JIT Compiler
~~~~~~~~~~~~
:ref:`Just-in-Time Compiler (JIT) <rpython:jit>`: we have a tracing JIT that traces the
interpreter written in RPython, rather than the user program that it
interprets.  As a result it applies to any interpreter, i.e. any
language.  But getting it to work correctly is not trivial: it
requires a small number of precise "hints" and possibly some small
refactorings of the interpreter.  The JIT itself also has several
almost-independent parts: the tracer itself in ``rpython/jit/metainterp``, the
optimizer in ``rpython/jit/metainterp/optimizer`` that optimizes a list of
residual operations, and the backend in ``rpython/jit/backend/<machine-name>``
that turns it into machine code.  Writing a new backend is a
traditional way to get into the project.

Garbage Collectors
~~~~~~~~~~~~~~~~~~
Garbage Collectors (GC): as you may notice if you are used to CPython's
C code, there are no ``Py_INCREF/Py_DECREF`` equivalents in RPython code.
:ref:`rpython:garbage-collection` is inserted
during translation.  Moreover, this is not reference counting; it is a real
GC written as more RPython code.  The best one we have so far is in
``rpython/memory/gc/incminimark.py``.

.. _`Getting Started with RPython`: https://rpython.readthedocs.io/en/latest/getting-started.html
.. _RPython By Example: https://mesapy.org/rpython-by-example/

