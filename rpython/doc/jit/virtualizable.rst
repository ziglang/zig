
Virtualizables
==============

**Note:** this document does not have a proper introduction as to how
to understand the basics. We should write some. If you happen to be here
and you're missing context, feel free to pester us on IRC.

Problem description
-------------------

The JIT is very good at making sure some objects are never allocated if they
don't escape from the trace. Such objects are called ``virtuals``. However,
if we're dealing with frames, virtuals are often not good enough. Frames
can escape and they can also be allocated already at the moment we enter the
JIT. In such cases we need some extra object that can still be optimized away,
despite existing on the heap.

Solution
--------

We introduce virtualizables. They're objects that exist on the heap, but their
fields are not always in sync with whatever happens in the assembler. One
example is that virtualizable fields can store virtual objects without
forcing them. This is very useful for frames. Declaring an object to be
virtualizable works like this:

.. code-block:: python

    class Frame(object):
       _virtualizable_ = ['locals[*]', 'stackdepth']


And we use them in ``JitDriver`` like this:

.. code-block:: python

    jitdriver = JitDriver(greens=[], reds=['frame'], virtualizables=['frame'])


This declaration means that ``stackdepth`` is a virtualizable **field**, while
``locals`` is a virtualizable **array** (a list stored on a virtualizable).
There are various rules about using virtualizables, especially using
virtualizable arrays that can be very confusing. Those will usually end
up with a compile-time error (as opposed to strange behavior). The rules are:

* A virtualizable array must be a fixed-size list.  After it is
  initialized (e.g. in ``Frame.__init__``) you cannot resize it at all.
  You cannot assign a different list to the field, or even pass around the
  list.  You can only access ``frame.array[index]`` directly.

* Each array access must be with a known positive index that cannot raise
  an ``IndexError``.
  Using ``index = jit.hint(index, promote=True)`` might be useful
  to get a constant-number access. This is only safe if the index is actually
  constant or changing rarely within the context of the user's code.

* If you initialize a new virtualizable in the JIT, it has to be done like this
  (for example if we're in ``Frame.__init__``):

  .. code-block:: python

      self = hint(self, access_directly=True, fresh_virtualizable=True)

  that way you can populate the fields directly.

* If you use virtualizable outside of the JIT – it's very expensive and
  sometimes aborts tracing. Consider it carefully as to how do it only for
  debugging purposes and not every time (e.g. ``sys._getframe`` call).

* If you have something equivalent of a Python generator, where the
  virtualizable survives for longer, you want to force it before returning.
  It's better to do it that way than by an external call some time later.
  It's done using ``jit.hint(frame, force_virtualizable=True)``

* Your interpreter should have a local variable similar to ``frame``
  above.  It must not be modified as long as it runs its
  ``jit_merge_point`` loop, and in the loop it must be passed directly
  to the ``jit_merge_point()`` and ``can_enter_jit()`` calls.  The JIT
  generator is known to produce buggy code if you fetch the
  virtualizable from somewhere every iteration, instead of reusing the
  same unmodified local variable.
