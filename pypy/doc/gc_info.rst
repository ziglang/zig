Garbage collector documentation and configuration
=================================================


Incminimark
-----------

PyPy's default garbage collector is called incminimark - it's an incremental,
generational moving collector. Here we hope to explain a bit how it works
and how it can be tuned to suit the workload.

Incminimark first allocates objects in so called *nursery* - place for young
objects, where allocation is very cheap, being just a pointer bump. The nursery
size is a very crucial variable - depending on your workload (one or many
processes) and cache sizes you might want to experiment with it via
*PYPY_GC_NURSERY* environment variable. When the nursery is full, there is
performed a minor collection. Freed objects are no longer referencable and
just die, just by not being referenced any more; on the other hand, objects
found to still be alive must survive and are copied from the nursery
to the old generation. Either to arenas, which are collections
of objects of the same size, or directly allocated with malloc if they're
larger.  (A third category, the very large objects, are initially allocated
outside the nursery and never move.)

Since Incminimark is an incremental GC, the major collection is incremental:
the goal is not to have any pause longer than 1ms, but in practice it depends
on the size and characteristics of the heap: occasionally, there can be pauses
between 10-100ms.


Semi-manual GC management
--------------------------

If there are parts of the program where it is important to have a low latency,
you might want to control precisely when the GC runs, to avoid unexpected
pauses.  Note that this has effect only on major collections, while minor
collections continue to work as usual.

As explained above, a full major collection consists of ``N`` steps, where
``N`` depends on the size of the heap; generally speaking, it is not possible
to predict how many steps will be needed to complete a collection.

``gc.enable()`` and ``gc.disable()`` control whether the GC runs collection
steps automatically.  When the GC is disabled the memory usage will grow
indefinitely, unless you manually call ``gc.collect()`` and
``gc.collect_step()``.

``gc.collect()`` runs a full major collection.

``gc.collect_step()`` runs a single collection step. It returns an object of
type GcCollectStepStats_, the same which is passed to the corresponding `GC
Hooks`_.  The following code is roughly equivalent to a ``gc.collect()``::

    while True:
        if gc.collect_step().major_is_done:
            break
  
For a real-world example of usage of this API, you can look at the 3rd-party
module `pypytools.gc.custom`_, which also provides a ``with customgc.nogc()``
context manager to mark sections where the GC is forbidden.

.. _`pypytools.gc.custom`: https://github.com/antocuni/pypytools/blob/master/pypytools/gc/custom.py


Fragmentation
-------------

Before we discuss issues of "fragmentation", we need a bit of precision.
There are two kinds of related but distinct issues:

* If the program allocates a lot of memory, and then frees it all by
  dropping all references to it, then we might expect to see the RSS
  to drop.  (RSS = Resident Set Size on Linux, as seen by "top"; it is an
  approximation of the actual memory usage from the OS's point of view.)
  This might not occur: the RSS may remain at its highest value.  This
  issue is more precisely caused by the process not returning "free"
  memory to the OS.  We call this case "unreturned memory".

* After doing the above, if the RSS didn't go down, then at least future
  allocations should not cause the RSS to grow more.  That is, the process
  should reuse unreturned memory as long as it has got some left.  If this
  does not occur, the RSS grows even larger and we have real fragmentation
  issues.


gc.get_stats
------------

There is a special function in the ``gc`` module called
``get_stats(memory_pressure=False)``.

``memory_pressure`` controls whether or not to report memory pressure from
objects allocated outside of the GC, which requires walking the entire heap,
so it's disabled by default due to its cost. Enable it when debugging
mysterious memory disappearance.

Example call looks like that::
    
    >>> gc.get_stats(True)
    Total memory consumed:
    GC used:            4.2MB (peak: 4.2MB)
       in arenas:            763.7kB
       rawmalloced:          383.1kB
       nursery:              3.1MB
    raw assembler used: 0.0kB
    memory pressure:    0.0kB
    -----------------------------
    Total:              4.2MB

    Total memory allocated:
    GC allocated:            4.5MB (peak: 4.5MB)
       in arenas:            763.7kB
       rawmalloced:          383.1kB
       nursery:              3.1MB
    raw assembler allocated: 0.0kB
    memory pressure:    0.0kB
    -----------------------------
    Total:                   4.5MB
    
In this particular case, which is just at startup, GC consumes relatively
little memory and there is even less unused, but allocated memory. In case
there is a lot of unreturned memory or actual fragmentation, the "allocated"
can be much higher than "used".  Generally speaking, "peak" will more closely
resemble the actual memory consumed as reported by RSS.  Indeed, returning
memory to the OS is a hard and not solved problem.  In PyPy, it occurs only if
an arena is entirely free---a contiguous block of 64 pages of 4 or 8 KB each.
It is also rare for the "rawmalloced" category, at least for common system
implementations of ``malloc()``.

The details of various fields:

* GC in arenas - small old objects held in arenas. If the amount "allocated"
  is much higher than the amount "used", we have unreturned memory.  It is
  possible but unlikely that we have internal fragmentation here.  However,
  this unreturned memory cannot be reused for any ``malloc()``, including the
  memory from the "rawmalloced" section.

* GC rawmalloced - large objects allocated with malloc.  This is gives the
  current (first block of text) and peak (second block of text) memory
  allocated with ``malloc()``.  The amount of unreturned memory or
  fragmentation caused by ``malloc()`` cannot easily be reported.  Usually
  you can guess there is some if the RSS is much larger than the total
  memory reported for "GC allocated", but do keep in mind that this total
  does not include malloc'ed memory not known to PyPy's GC at all.  If you
  guess there is some, consider using `jemalloc`_ as opposed to system malloc.

.. _`jemalloc`: http://jemalloc.net/

* nursery - amount of memory allocated for nursery, fixed at startup,
  controlled via an environment variable

* raw assembler allocated - amount of assembler memory that JIT feels
  responsible for

* memory pressure, if asked for - amount of memory we think got allocated
  via external malloc (eg loading cert store in SSL contexts) that is kept
  alive by GC objects, but not accounted in the GC


GC Hooks
--------

GC hooks are user-defined functions which are called whenever a specific GC
event occur, and can be used to monitor GC activity and pauses.  You can
install the hooks by setting the following attributes:

``gc.hook.on_gc_minor``
    Called whenever a minor collection occurs. It corresponds to
    ``gc-minor`` sections inside ``PYPYLOG``.

``gc.hook.on_gc_collect_step``
    Called whenever an incremental step of a major collection occurs. It
    corresponds to ``gc-collect-step`` sections inside ``PYPYLOG``.

``gc.hook.on_gc_collect``
    Called after the last incremental step, when a major collection is fully
    done. It corresponds to ``gc-collect-done`` sections inside ``PYPYLOG``.

To uninstall a hook, simply set the corresponding attribute to ``None``.  To
install all hooks at once, you can call ``gc.hooks.set(obj)``, which will look
for methods ``on_gc_*`` on ``obj``.  To uninstall all the hooks at once, you
can call ``gc.hooks.reset()``.

The functions called by the hooks receive a single ``stats`` argument, which
contains various statistics about the event.

Note that PyPy cannot call the hooks immediately after a GC event, but it has
to wait until it reaches a point in which the interpreter is in a known state
and calling user-defined code is harmless.  It might happen that multiple
events occur before the hook is invoked: in this case, you can inspect the
value ``stats.count`` to know how many times the event occurred since the last
time the hook was called.  Similarly, ``stats.duration`` contains the
**total** time spent by the GC for this specific event since the last time the
hook was called.

On the other hand, all the other fields of the ``stats`` object are relative
only to the **last** event of the series.

The attributes for ``GcMinorStats`` are:

``count``
    The number of minor collections occurred since the last hook call.

``duration``
    The total time spent inside minor collections since the last hook
    call, in seconds.

``duration_min``
    The duration of the fastest minor collection since the last hook call.
    
``duration_max``
    The duration of the slowest minor collection since the last hook call.

 ``total_memory_used``
    The amount of memory used at the end of the minor collection, in
    bytes. This include the memory used in arenas (for GC-managed memory) and
    raw-malloced memory (e.g., the content of numpy arrays).

``pinned_objects``
    the number of pinned objects.


.. _GcCollectStepStats:

The attributes for ``GcCollectStepStats`` are:

``count``, ``duration``, ``duration_min``, ``duration_max``
    See above.

``oldstate``, ``newstate``
    Integers which indicate the state of the GC before and after the step.

``major_is_done``
    Boolean which indicate whether this was the last step of the major
    collection

The value of ``oldstate`` and ``newstate`` is one of these constants, defined
inside ``gc.GcCollectStepStats``: ``STATE_SCANNING``, ``STATE_MARKING``,
``STATE_SWEEPING``, ``STATE_FINALIZING``, ``STATE_USERDEL``.  It is possible
to get a string representation of it by indexing the ``GC_STATES`` tuple.


The attributes for ``GcCollectStats`` are:

``count``
    See above.

``num_major_collects``
    The total number of major collections which have been done since the
    start. Contrarily to ``count``, this is an always-growing counter and it's
    not reset between invocations.

``arenas_count_before``, ``arenas_count_after``
    Number of arenas used before and after the major collection.

``arenas_bytes``
    Total number of bytes used by GC-managed objects.

``rawmalloc_bytes_before``, ``rawmalloc_bytes_after``
    Total number of bytes used by raw-malloced objects, before and after the
    major collection.

Note that ``GcCollectStats`` has **not** got a ``duration`` field. This is
because all the GC work is done inside ``gc-collect-step``:
``gc-collect-done`` is used only to give additional stats, but doesn't do any
actual work.

Here is an example of GC hooks in use::

    import sys
    import gc

    class MyHooks(object):
        done = False

        def on_gc_minor(self, stats):
            print 'gc-minor:        count = %02d, duration = %d' % (stats.count,
                                                                    stats.duration)

        def on_gc_collect_step(self, stats):
            old = gc.GcCollectStepStats.GC_STATES[stats.oldstate]
            new = gc.GcCollectStepStats.GC_STATES[stats.newstate]
            print 'gc-collect-step: %s --> %s' % (old, new)
            print '                 count = %02d, duration = %d' % (stats.count,
                                                                    stats.duration)

        def on_gc_collect(self, stats):
            print 'gc-collect-done: count = %02d' % stats.count
            self.done = True

    hooks = MyHooks()
    gc.hooks.set(hooks)

    # simulate some GC activity
    lst = []
    while not hooks.done:
        lst = [lst, 1, 2, 3]


.. _minimark-environment-variables:

Environment variables
---------------------

PyPy's default ``incminimark`` garbage collector is configurable through
several environment variables:

``PYPY_GC_NURSERY``
    The nursery size.
    Defaults to 1/2 of your last-level cache, or ``4M`` if unknown.
    Small values (like 1 or 1KB) are useful for debugging.

``PYPY_GC_NURSERY_DEBUG``
    If set to non-zero, will fill nursery with garbage, to help
    debugging.

``PYPY_GC_INCREMENT_STEP``
    The size of memory marked during the marking step.  Default is size of
    nursery times 2. If you mark it too high your GC is not incremental at
    all.  The minimum is set to size that survives minor collection times
    1.5 so we reclaim anything all the time.

``PYPY_GC_MAJOR_COLLECT``
    Major collection memory factor.
    Default is ``1.82``, which means trigger a major collection when the
    memory consumed equals 1.82 times the memory really used at the end
    of the previous major collection.

``PYPY_GC_GROWTH``
    Major collection threshold's max growth rate.
    Default is ``1.4``.
    Useful to collect more often than normally on sudden memory growth,
    e.g. when there is a temporary peak in memory usage.

``PYPY_GC_MAX``
    The max heap size.
    If coming near this limit, it will first collect more often, then
    raise an RPython MemoryError, and if that is not enough, crash the
    program with a fatal error.
    Try values like ``1.6GB``.

``PYPY_GC_MAX_DELTA``
    The major collection threshold will never be set to more than
    ``PYPY_GC_MAX_DELTA`` the amount really used after a collection.
    Defaults to 1/8th of the total RAM size (which is constrained to be
    at most 2/3/4GB on 32-bit systems).
    Try values like ``200MB``.

``PYPY_GC_MIN``
    Don't collect while the memory size is below this limit.
    Useful to avoid spending all the time in the GC in very small
    programs.
    Defaults to 8 times the nursery.

``PYPY_GC_DEBUG``
    Enable extra checks around collections that are too slow for normal
    use.
    Values are ``0`` (off), ``1`` (on major collections) or ``2`` (also
    on minor collections).

``PYPY_GC_MAX_PINNED``
    The maximal number of pinned objects at any point in time.  Defaults
    to a conservative value depending on nursery size and maximum object
    size inside the nursery.  Useful for debugging by setting it to 0.
