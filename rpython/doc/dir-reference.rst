RPython directory cross-reference
=================================

Here is a fully referenced alphabetical two-level deep
directory overview of RPython:

========================================  ============================================
Directory                                 explanation/links
========================================  ============================================
:source:`rpython/annotator/`              :ref:`type inferencing code <annotator>` for
                                          :doc:`RPython <rpython>` programs

:source:`rpython/config/`                 handles the numerous options for RPython

:source:`rpython/flowspace/`              the :ref:`flow graph builder<flow-graphs>` implementing
                                          `abstract interpretation`_

:source:`rpython/rlib/`                   a :doc:`"standard library" <rlib>` for :doc:`RPython <rpython>`
                                          programs

:source:`rpython/rtyper/`                 the :ref:`RPython Typer <rtyper>`

:source:`rpython/rtyper/lltypesystem/`    the :ref:`low-level type system <low-level-types>` for
                                          C-like backends

:source:`rpython/memory/`                 the :doc:`garbage collector <garbage_collection>` construction
                                          framework

:source:`rpython/tool/algo/`              general-purpose algorithmic and mathematic tools

:source:`rpython/translator/`             :doc:`translation <translation>` backends and support code

:source:`rpython/translator/backendopt/`  general optimizations that run before a
                                          backend generates code

:source:`rpython/translator/c/`           the :ref:`GenC backend <genc>`, producing C code
                                          from an RPython program (generally via the :doc:`rtyper <rtyper>`)

:source:`rpython/translator/jvm/`         the Java backend

:source:`rpython/translator/tool/`        helper tools for translation

:source:`dotviewer/`                      :ref:`graph viewer <try-out-the-translator>`
========================================  ============================================

.. _abstract interpretation: http://en.wikipedia.org/wiki/Abstract_interpretation
.. _.NET: http://www.microsoft.com/net/
.. _Mono: http://www.mono-project.com/
