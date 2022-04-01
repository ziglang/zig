If this option is used, then PyPy imports and generates "pyc" files in the
same way as CPython.  This is true by default and there is not much reason
to turn it off nowadays.  If off, PyPy never produces "pyc" files and
ignores any "pyc" file that might already be present.
