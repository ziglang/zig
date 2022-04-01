.. _tproxy:

Transparent Proxies (DEPRECATED)
--------------------------------

.. warning::

    This is a feature that was tried experimentally long ago, and we
    found no really good use cases.  The basic functionality is still
    there, but we don't recommend using it.  Some of the examples below
    might not work any more (e.g. you can't tproxy a list object any
    more).  The rest can be done by hacking in standard Python.  If
    anyone is interested in working on tproxy again, he is welcome, but
    we don't regard this as an interesting extension.

PyPy's Transparent Proxies allow routing of operations on objects
to a callable.  Application-level code can customize objects without
interfering with the type system - ``type(proxied_list) is list`` holds true
when :py:obj:`proxied_list` is a proxied built-in :py:class:`list` - while
giving you full control on all operations that are performed on the
:py:obj:`proxied_list`.

See [D12.1]_ for more context, motivation and usage of transparent proxies.


Example of the core mechanism
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The following example proxies a list and will return ``42`` on any addition
operations::

   $ py.py --objspace-std-withtproxy
   >>>> from __pypy__ import tproxy
   >>>> def f(operation, *args, **kwargs):
   >>>>    if operation == '__add__':
   >>>>         return 42
   >>>>    raise AttributeError
   >>>>
   >>>> i = tproxy(list, f)
   >>>> type(i)
   list
   >>>> i + 3
   42


Example of recording all operations on builtins
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Suppose we want to have a list which stores all operations performed on
it for later analysis.  We can use the :source:`lib_pypy/tputil.py` module to help
with transparently proxying builtin instances::

   from tputil import make_proxy

   history = []
   def recorder(operation):
       history.append(operation)
       return operation.delegate()

   >>>> l = make_proxy(recorder, obj=[])
   >>>> type(l)
   list
   >>>> l.append(3)
   >>>> len(l)
   1
   >>>> len(history)
   2

``make_proxy(recorder, obj=[])`` creates a transparent list
proxy that allows us to delegate operations to the :py:func:`recorder` function.
Calling ``type(l)`` does not lead to any operation being executed at all.

Note that :py:meth:`append` shows up as :py:meth:`__getattribute__` and that
``type(l)`` does not show up at all - the type is the only aspect of the instance
which the proxy controller cannot change.


.. _transparent proxy builtins:

Transparent Proxy PyPy builtins and support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you are using the `--objspace-std-withtproxy`_ option
the :doc:`__pypy__ <__pypy__-module>` module provides the following builtins:

.. py:function:: tproxy(type, controller)

   Returns a proxy object representing the given type and forwarding all
   operations on this type to the controller.  On each operation,
   ``controller(opname, *args, **kwargs)`` will be called.

.. py:function:: get_tproxy_controller(obj)

   Returns the responsible controller for a given object.  For non-proxied
   objects :py:const:`None` is returned.

.. _--objspace-std-withtproxy: config/objspace.std.withtproxy.html


.. _tputil:

tputil helper module
~~~~~~~~~~~~~~~~~~~~

The :source:`lib_pypy/tputil.py` module provides:

.. py:function:: make_proxy(controller, type, obj)

   Creates a transparent proxy controlled by the given :py:obj:`controller`
   callable.  The proxy will appear as a completely regular instance of the given
   type, but all operations on it are sent to the specified controller - which
   receives a :py:class:`ProxyOperation` instance on each operation. If :py:obj:`type`
   is not specified, it defaults to ``type(obj)`` if :py:obj:`obj` is specified.

   ProxyOperation instances have the following attributes:

   .. py:attribute:: proxyobj

      The transparent proxy object of this operation.

   .. py:attribute:: opname

      The name of this operation.

   .. py:attribute:: args

      Any positional arguments for this operation.

   .. py:attribute:: kwargs

      Any keyword arguments for this operation.

   .. py:attribute:: obj

      (Only if provided to :py:func:`make_proxy`)

      A concrete object.

   .. py:method:: delegate

      If a concrete object instance :py:obj:`obj` was specified in the call to
      :py:func:`make_proxy`, then :py:meth:`proxyoperation.delegate` can be called
      to delegate the operation to the object instance.


Further points of interest
~~~~~~~~~~~~~~~~~~~~~~~~~~

A lot of tasks could be performed using transparent proxies, including,
but not limited to:

* Remote versions of objects, on which we can directly perform operations
  (think about transparent distribution)

* Access to persistent storage such as a database (imagine an
  SQL object mapper which looks like any other object).

* Access to external data structures, such as other languages, as normal
  objects (of course some operations could raise exceptions, but
  since operations are executed at the application level, that is not a major
  problem)


Implementation Notes
~~~~~~~~~~~~~~~~~~~~

PyPy's standard object space allows us to internally have multiple
implementations of a type and change the implementation at run-time, while
application-level code consistently sees the exact same type and object.
Multiple performance optimizations using these features have already been
implemented: :doc:`alternative object implementations <interpreter-optimizations>`.
Transparent Proxies use this architecture to provide control back to
application-level code.

Transparent proxies are implemented on top of the :ref:`standard object
space <standard-object-space>`, in :source:`pypy/objspace/std/proxyobject.py`,
:source:`pypy/objspace/std/proxyobject.py` and :source:`pypy/objspace/std/transparent.py`.
To use them you will need to pass a `--objspace-std-withtproxy`_ option to ``pypy``
or ``translate.py``.  This registers implementations named :py:class:`W_TransparentXxx`
- which usually correspond to an appropriate :py:class:`W_XxxObject` - and
includes some interpreter hacks for objects that are too close to the interpreter
to be implemented in the standard object space. The types of objects that can
be proxied this way are user created classes & functions,
lists, dicts, exceptions, tracebacks and frames.

.. [D12.1] `High-Level Backends and Interpreter Feature Prototypes`, PyPy
           EU-Report, 2007, https://bitbucket.org/pypy/extradoc/raw/tip/eu-report/D12.1_H-L-Backends_and_Feature_Prototypes-2007-03-22.pdf
