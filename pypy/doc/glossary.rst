.. _glossary:

Glossary
========

.. if you add new entries, keep the alphabetical sorting and formatting!

.. glossary::

   application level
      :ref:`applevel<application-level>` code is normal Python code running on top of the PyPy or
      :term:`CPython` interpreter (see :term:`interpreter level`)

   CPython
      The "default" implementation of Python, written in C and
      distributed by the PSF_ on https://www.python.org.

   interpreter level
      Code running at this level is part of the implementation of the
      PyPy interpreter and cannot interact normally with :term:`application
      level` code; it typically provides implementation for an object
      space and its builtins.

   mixed module
      a module that accesses PyPy's :term:`interpreter level`.  The name comes
      from the fact that the module's implementation can be a mixture of
      :term:`application level` and :term:`interpreter level` code.

   object space
      :doc:`objspace` (often abbreviated to
      "objspace") creates all objects and knows how to perform operations
      on the objects. You may think of an object space as being a library
      offering a fixed API, a set of operations, with implementations
      that a) correspond to the known semantics of Python objects, b)
      extend or twist these semantics, or c) serve whole-program analysis
      purposes.

   stackless
      Technology that enables various forms of non conventional control
      flow, such as coroutines, greenlets and tasklets.  Inspired by
      Christian Tismer's `Stackless Python <https://www.stackless.com>`__.

   standard interpreter
      It is the :ref:`subsystem implementing the Python language <python-interpreter>`, composed
      of the bytecode interpreter and of the standard objectspace.

    prebuilt constant
       In :term:`RPython` module globals are considered constants.  Moreover,
       global (i.e. prebuilt) lists and dictionaries are supposed to be
       immutable ("prebuilt constant" is sometimes abbreviated to "pbc").

.. _PSF: https://www.python.org/psf/
