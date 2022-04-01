=========================
What's new in PyPy 4.0.1
=========================

.. this is a revision shortly after release-4.0.0
.. startrev: 57c9a47c70f6

.. branch: 2174-fix-osx-10-11-translation

Use pkg-config to find ssl headers on OS-X

.. branch: Zearin/minor-whatsnewrst-markup-tweaks-edited-o-1446387512092

.. branch: ppc-stacklet

The PPC machines now support the _continuation module (stackless, greenlets)

.. branch: int_0/i-need-this-library-to-build-on-ubuntu-1-1446717626227

Document that libgdbm-dev is required for translation/packaging

.. branch: propogate-nans

Ensure that ndarray conversion from int16->float16->float32->float16->int16
preserves all int16 values, even across nan conversions. Also fix argmax, argmin
for nan comparisons

.. branch: array_interface

Support common use-cases for __array_interface__, passes upstream tests

.. branch: no-class-specialize

Some refactoring of class handling in the annotator. 
Remove class specialisation and _settled_ flag.
