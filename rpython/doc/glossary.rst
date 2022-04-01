.. _glossary:

Glossary
========

.. if you add new entries, keep the alphabetical sorting and formatting!

.. glossary::

   annotator
      The component of the :term:`RPython toolchain` that performs a form
      of :term:`type inference` on the flow graph. See :ref:`annotator`
      in the documentation.

   backend
      Code generator that converts an :doc:`rpython` program to a :ref:`target
      language <try-out-the-translator>` using the :term:`RPython toolchain`.

   compile-time
      In the context of the :term:`JIT`, compile time is when the JIT is
      generating machine code "just in time".

   external function
      Functions that we don't want to implement in Python for various
      reasons (e.g. they need to make calls into the OS) and whose
      implementation will be provided by the backend.

   garbage collection framework
      Code that makes it possible to write :doc:`RPython's garbage collectors <garbage_collection>`
      in Python itself.

   guard
      a small test that checks if assumptions the JIT makes during tracing are still true

   JIT
      :doc:`just in time compiler <jit/index>`.

   llinterpreter
      Piece of code that is able to interpret flow graphs.  This is very
      useful for testing purposes, especially if you work on the :term:`RPython`
      Typer.

   lltypesystem
      A :ref:`C-like type model <low-level-types>` that contains
      structs and pointers.  A :term:`backend` that uses this type system is also
      called a low-level backend.  The C backend uses this
      typesystem.

   low-level helper
      A function that the :term:`RTyper` can use a call to as part of implementing
      some operation in terms of the target :term:`type system`.

   ootypesystem
      An object oriented type model <oo-type>
      containing classes and instances.  A :term:`backend` that uses this type system
      is also called a high-level backend.  The JVM and CLI backends (now removed)
      used this typesystem.

   prebuilt constant
      In :term:`RPython` module globals are considered constants.  Moreover,
      global (i.e. prebuilt) lists and dictionaries are supposed to be
      immutable ("prebuilt constant" is sometimes abbreviated to "pbc").

   promotion
      :term:`JIT` terminology.  *promotion* is a way of "using" a :term:`run-time`
      value at :term:`compile-time`, essentially by deferring compilation
      until the run-time value is known. See if :doc:`the jit docs <jit/index>` help.

   RPython
      :doc:`rpython`, a limited subset of the Python_ language.
      The limitations make :term:`type inference` possible.
      It is also the language that the PyPy interpreter itself is written
      in.

   RPython toolchain
      :ref:`annotator`, :doc:`rtyper`, and various :term:`backend`\ s.

   rtyper
      Based on the type annotations, :doc:`rtyper` turns the flow
      graph into one that fits the model of the target platform/:term:`backend`
      using either the :term:`lltypesystem` or the :term:`ootypesystem`.

   run-time
      In the context of the :term:`JIT`, run time is when the code the JIT has
      generated is executing.

   specialization
      A way of controlling how a specific function is handled by the
      :term:`annotator`.  One specialization is to treat calls to a function
      with different argument types as if they were calls to different
      functions with identical source.

   transformation
      Code that modifies flowgraphs to weave in translation aspects

   translation-time
      In the context of the :term:`JIT`, translation time is when the PyPy
      source is being analyzed and the JIT itself is being created.

   translator
     :ref:`Tool <try-out-the-translator>` based on the PyPy interpreter which can translate
     sufficiently static Python programs into low-level code.

   type system
      The RTyper can target either the :term:`lltypesystem` or the :term:`ootypesystem`.

   type inference
      Deduces either partially or fully the type of expressions as
      described in this `type inference article on Wikipedia`_.
      The :term:`RPython toolchain`'s flavour of type inference is described
      in :ref:`annotator` section.

.. _type inference article on Wikipedia: http://en.wikipedia.org/wiki/Type_inference
.. _Python: http://www.python.org
