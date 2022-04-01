This optimization converts parts of flow graphs that result from
chains of ifs and elifs like this into merged blocks.

By default flow graphing this kind of code::

    if x == 0:
        f()
    elif x == 1:
        g()
    elif x == 4:
        h()
    else:
        j()

will result in a chain of blocks with two exits, somewhat like this:

.. image:: unmergedblocks.png

(reflecting how Python would interpret this code).  Running this
optimization will transform the block structure to contain a single
"choice block" with four exits:

.. image:: mergedblocks.png

This can then be turned into a switch by the C backend, allowing the C
compiler to produce more efficient code.
