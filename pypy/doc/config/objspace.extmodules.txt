You can pass a comma-separated list of third-party builtin modules
which should be translated along with the standard modules within
``pypy.module``.

The module names need to be fully qualified (i.e. have a ``.`` in them),
be on the ``$PYTHONPATH`` and not conflict with any existing ones, e.g.
``mypkg.somemod``.

Once translated, the module will be accessible with a simple::

    import somemod

