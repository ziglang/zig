.. _trace_optimizer:

Trace Optimizer
===============

Traces of user programs are not directly translated into machine code.
The optimizer module implements several different semantic preserving
transformations that either allow operations to be swept from the trace
or convert them to operations that need less time or space.

The optimizer is in `rpython/jit/metainterp/optimizeopt/`.
When you try to make sense of this module, this page might get you started.

Before some optimizations are explained in more detail, it is essential to
understand how traces look like.
The optimizer comes with a test suite. It contains many trace
examples and you might want to take a look at it
(in `rpython/jit/metainterp/optimizeopt/test/*.py`).
The allowed operations can be found in `rpython/jit/metainterp/resoperation.py`.
Here is an example of a trace::

    [p0,i0,i1]
    label(p0, i0, i1)
    i2 = getarrayitem_raw(p0, i0, descr=<Array Signed>)
    i3 = int_add(i1,i2)
    i4 = int_add(i0,1)
    i5 = int_le(i4, 100) # lower-or-equal
    guard_true(i5)
    jump(p0, i4, i3)

At the beginning it might be clumsy to read but it makes sense when you start
to compare the Python code that constructed the trace::

    from array import array
    a = array('i', range(101))
    sum = 0; i = 0
    while i <= 100: # can be seen as label
        sum += a[i]
        i += 1
        # jumps back to the while header

There are better ways to compute the sum from ``[0..100]``, but it gives a better intuition on how
traces are constructed than ``sum(range(101))``.
Note that the trace syntax is the one used in the test suite. It is also very
similar to traces printed at runtime by :doc:`PYPYLOG <../logging>`. The first
line gives the input variables, the second line is a ``label`` operation, the
last one is the backwards ``jump`` operation.

These instructions mentioned earlier are special:

* the input defines the input parameter type and name to enter the trace.
* ``label`` is the instruction a ``jump`` can target. Label instructions have
  a ``JitCellToken`` associated that uniquely identifies the label. Any jump
  has a target token of a label.

The token is saved in a so called `descriptor` of the instruction. It is
not written explicitly because it is not done in the tests either. But
the test suite creates a dummy token for each trace and adds it as descriptor
to ``label`` and ``jump``. Of course the optimizer does the same at runtime,
but using real values.
The sample trace includes a descriptor in ``getarrayitem_raw``. Here it
annotates the type of the array. It is a signed integer array.

High level overview
-------------------

Before the JIT backend transforms any trace into machine code, it tries to
transform the trace into an equivalent trace that executes faster. The method
`optimize_trace` in `rpython/jit/metainterp/optimizeopt/__init__.py` is the
main entry point.

Optimizations are applied in a sequence one after another and the base
sequence is as follows::

    intbounds:rewrite:virtualize:string:earlyforce:pure:heap:unroll

Each of the colon-separated name has a class attached, inheriting from
the `Optimization` class.  The `Optimizer` class itself also
derives from the `Optimization` class and implements the control logic for
the optimization. Most of the optimizations only require a single forward pass.
The trace is 'propagated' into each optimization using the method
`propagate_forward`. Instruction by instruction, it flows from the
first optimization to the last optimization. The method `emit_operation`
is called for every operation that is passed to the next optimizer.

A frequently encountered pattern
--------------------------------

To find potential optimization targets it is necessary to know the instruction
type. Simple solution is to switch using the operation number (= type)::

    for op in operations:
        if op.getopnum() == rop.INT_ADD:
            # handle this instruction
            pass
        elif op.getopnum() == rop.INT_FLOOR_DIV:
            pass
        # and many more

Things get worse if you start to match the arguments
(is argument one constant and two variable or vice versa?). The pattern to tackle
this code bloat is to move it to a separate method using
`make_dispatcher_method`. It associates methods with instruction types::

    class OptX(Optimization):
        def prefix_INT_ADD(self, op):
            pass # emit, transform, ...

    dispatch_opt = make_dispatcher_method(OptX, 'prefix_',
                                          default=OptX.emit_operation)
    OptX.propagate_forward = dispatch_opt

    optX = OptX()
    for op in operations:
        optX.propagate_forward(op)

``propagate_forward`` searches for the method that is able to handle the instruction
type. As an example `INT_ADD` will invoke `prefix_INT_ADD`. If there is no function
for the instruction, it is routed to the default implementation (``emit_operation``
in this example).

Rewrite optimization
--------------------

The second optimization is called 'rewrite' and is commonly also known as
strength reduction. A simple example would be that an integer multiplied
by 2 is equivalent to the bits shifted to the left once
(e.g. ``x * 2 == x << 1``). Not only strength reduction is done in this
optimization but also boolean or arithmetic simplifications. Other examples
would be: ``x & 0 == 0``, ``x - 0 == x``

Whenever such an operation is encountered (e.g. ``y = x & 0``), no operation is
emitted. Instead the variable y is made equal to 0
(= ``make_constant_int(op, 0)``). The variables found in a trace are instances
of classes that can be found in `rpython/jit/metainterp/history.py`. When a
value is made equal to another, its box is made to point to the other one.


Pure optimization
-----------------

The 'pure' optimizations interwoven into the basic optimizer. It saves
operations, results, arguments to be known to have pure semantics.

"Pure" here means the same as the ``jit.elidable`` decorator:
free of "observable" side effects and referentially transparent
(the operation can be replaced with its result without changing the program
semantics). The operations marked as ALWAYS_PURE in `resoperation.py` are a
subset of the NOSIDEEFFECT operations. Operations such as new, new array,
getfield_(raw/gc) are marked as NOSIDEEFFECT but not as ALWAYS_PURE.

Pure operations are optimized in two different ways.  If their arguments
are constants, the operation is removed and the result is turned into a
constant.  If not, we can still use a memoization technique: if, later,
we see the same operation on the same arguments again, we don't need to
recompute its result, but can simply reuse the previous operation's
result.

Unroll optimization
-------------------

A detailed description can be found the document
`Loop-Aware Optimizations in PyPy's Tracing JIT`__

.. __: http://www2.maths.lth.se/matematiklth/vision/publdb/reports/pdf/ardo-bolz-etal-dls-12.pdf

This optimization does not fall into the traditional scheme of one forward
pass only. In a nutshell it unrolls the trace _once_, connects the two
traces (by inserting parameters into the jump and label of the peeled trace)
and uses information to iron out allocations, propagate constants and
do any other optimization currently present in the 'optimizeopt' module.

It is prepended to all optimizations and thus extends the Optimizer class
and unrolls the loop once before it proceeds.

Vectorization
-------------

- :doc:`Vectorization <vectorization>`

What is missing from this document
----------------------------------

* Guards are not explained
* Several optimizations are not explained


Further references
------------------

* `Allocation Removal by Partial Evaluation in a Tracing JIT`__
* `Loop-Aware Optimizations in PyPy's Tracing JIT`__

.. __: http://www.stups.uni-duesseldorf.de/mediawiki/images/b/b0/Pub-BoCuFiLePeRi2011.pdf
.. __: http://www2.maths.lth.se/matematiklth/vision/publdb/reports/pdf/ardo-bolz-etal-dls-12.pdf
