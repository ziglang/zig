PyPy's ctypes implementation
============================

Summary
--------

Terminology:

* application level code - code written in full Python

* interpreter level code - code written in RPython, compiled
  to something else, say C, part of the interpreter.

PyPy's ctypes implementation in its current state proves the
feasibility of implementing a module with the same interface and
behavior for PyPy as ctypes for CPython.

PyPy's implementation internally uses `libffi`_ like CPython's ctypes.
In our implementation as much as possible of the code is written in
full Python, not RPython. In CPython's situation, the equivalent would
be to write as little as possible code in C.  We essentially favored
rapid experimentation over worrying about speed for this first trial
implementation. This allowed to provide a working implementation with
a large part of ctypes features in 2 months real time.

We reused the ``ctypes`` package version 1.0.2 as-is from CPython. We
implemented ``_ctypes`` which is a C module in CPython mostly in pure
Python based on a lower-level layer extension module ``_rawffi``.

.. _libffi: http://sources.redhat.com/libffi/


Low-level part: ``_rawffi``
---------------------------

This PyPy extension module (:source:`pypy/module/_rawffi`) exposes a simple interface
to create C objects (arrays and structures) and calling functions
in dynamic libraries through libffi. Freeing objects in most cases and making
sure that objects referring to each other are kept alive is responsibility of the higher levels.

This module uses bindings to libffi which are defined in :source:`rpython/rlib/libffi.py`.

We tried to keep this module as small as possible. It is conceivable
that other implementations (e.g. Jython) could use our ctypes
implementation by writing their version of ``_rawffi``.


High-level parts
-----------------

The reused ``ctypes`` package lives in ``lib_pypy/ctypes``. ``_ctypes``
implementing the same interface as ``_ctypes`` in CPython is in
``lib_pypy/_ctypes``.


Discussion and limitations
-----------------------------

Reimplementing ctypes features was in general possible. PyPy supports
pluggable garbage collectors, some of them are moving collectors, this
means that the strategy of passing direct references inside Python
objects to an external library is not feasible (unless the GCs
support pinning, which is not the case right now).  The consequence of
this is that sometimes copying instead of sharing is required, this
may result in some semantics differences. C objects created with
_rawffi itself are allocated outside of the GC heap, such that they can be
passed to external functions without worries.

Porting the implementation to interpreter-level should likely improve
its speed.  Furthermore the current layering and the current _rawffi
interface require more object allocations and copying than strictly
necessary; this too could be improved.

Here is a list of the limitations and missing features of the
current implementation:

* ``ctypes.pythonapi`` is missing.  In previous versions, it was present
  and redirected to the `cpyext` C API emulation layer, but our
  implementation did not do anything sensible about the GIL and the
  functions were named with an extra "Py", for example
  ``PyPyInt_FromLong()``.  It was removed for being unhelpful.

* We copy Python strings instead of having pointers to raw buffers

* Features we did not get to implement:

  - custom alignment and bit-fields

  - resizing (``resize()`` function)

  - non-native byte-order objects

  - callbacks accepting by-value structures

  - slight semantic differences that ctypes makes
    between its primitive types and user subclasses
    of its primitive types


Running application examples
------------------------------

`pyglet`_ is known to run. We also had some success with pygame-ctypes (which is no longer maintained) and with a snapshot of the experimental pysqlite-ctypes. We will only describe how to run the pyglet examples.


pyglet
~~~~~~

We tried pyglet checking it out from its repository at revision 1984.

From pyglet, the following examples are known to work:

  - opengl.py
  - multiple_windows.py
  - events.py
  - html_label.py
  - timer.py
  - window_platform_event.py
  - fixed_resolution.py

The pypy-c translated to run the ctypes tests can be used to run the pyglet examples as well. They can be run like e.g.::

    $ cd pyglet/
    $ PYTHONPATH=. ../ctypes-stable/pypy/goal/pypy-c examples/opengl.py


they usually should be terminated with ctrl-c. Refer to the their doc strings for details about how they should behave.

The following examples don't work for reasons independent from ctypes:

  - image_convert.py needs PIL
  - image_display.py needs PIL
  - astraea/astraea.py needs PIL

We did not try the following examples:

  - media_player.py needs avbin or at least a proper sound card setup for
    .wav files
  - video.py needs avbin
  - soundscape needs avbin

.. _pyglet: http://pyglet.org/

