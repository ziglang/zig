This optimization enables "malloc removal", which "explodes"
allocations of structures which do not escape from the function they
are allocated in into one or more additional local variables.

An example.  Consider this rather unlikely seeming code::

    class C:
        pass
    def f(y):
        c = C()
        c.x = y
        return c.x

Malloc removal will spot that the ``C`` object can never leave ``f``
and replace the above with code like this::

    def f(y):
        _c__x = y
        return _c__x

It is rare for code to be directly written in a way that allows this
optimization to be useful, but inlining often results in opportunities
for its use (and indeed, this is one of the main reasons PyPy does its
own inlining rather than relying on the C compilers).

For much more information about this and other optimizations you can
read section 4.1 of the technical report on "Massive Parallelism and
Translation Aspects" which you can find on the `Technical reports page
<../index-report.html>`__.
