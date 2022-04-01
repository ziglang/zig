import pytest


def importorskip(name):
    try:
        return __import__(name)
    except ImportError:
        pytest.skip('Module %s not available' % name)


class MarkGenerator:
    """ Factory for :class:`MarkDecorator` objects - exposed as
    a ``pytest.mark`` singleton instance.  Example::

         import pytest
         @pytest.mark.slowtest
         def test_function():
            pass

    will set a 'slowtest' :class:`MarkInfo` object
    on the ``test_function`` object. """

    def __getattr__(self, name):
        if name[0] == "_":
            raise AttributeError("Marker name must NOT start with underscore")
        return MarkDecorator(name)

mark = MarkGenerator()

def istestfunc(func):
    return hasattr(func, "__call__") and \
        getattr(func, "__name__", "<lambda>") != "<lambda>"

class MarkDecorator:
    """ A decorator for test functions and test classes.  When applied
    it will create :class:`MarkInfo` objects which may be
    :ref:`retrieved by hooks as item keywords <excontrolskip>`.
    MarkDecorator instances are often created like this::

        mark1 = pytest.mark.NAME              # simple MarkDecorator
        mark2 = pytest.mark.NAME(name1=value) # parametrized MarkDecorator

    and can then be applied as decorators to test functions::

        @mark2
        def test_function():
            pass

    When a MarkDecorator instance is called it does the following:
      1. If called with a single class as its only positional argument and no
         additional keyword arguments, it attaches itself to the class so it
         gets applied automatically to all test cases found in that class.
      2. If called with a single function as its only positional argument and
         no additional keyword arguments, it attaches a MarkInfo object to the
         function, containing all the arguments already stored internally in
         the MarkDecorator.
      3. When called in any other case, it performs a 'fake construction' call,
         i.e. it returns a new MarkDecorator instance with the original
         MarkDecorator's content updated with the arguments passed to this
         call.

    Note: The rules above prevent MarkDecorator objects from storing only a
    single function or class reference as their positional argument with no
    additional keyword or positional arguments.

    """
    def __init__(self, name, args=None, kwargs=None):
        self.name = name
        self.args = args or ()
        self.kwargs = kwargs or {}

    def __repr__(self):
        d = self.__dict__.copy()
        name = d.pop('name')
        return "<MarkDecorator %r %r>" % (name, d)

    def __call__(self, *args, **kwargs):
        """ if passed a single callable argument: decorate it with mark info.
            otherwise add *args/**kwargs in-place to mark information. """
        if args and not kwargs:
            func = args[0]
            if len(args) == 1 and istestfunc(func):
                holder = getattr(func, self.name, None)
                if holder is None:
                    holder = MarkInfo(
                        self.name, self.args, self.kwargs
                    )
                    setattr(func, self.name, holder)
                else:
                    holder.add(self.args, self.kwargs)
                return func
        kw = self.kwargs.copy()
        kw.update(kwargs)
        args = self.args + args
        return self.__class__(self.name, args=args, kwargs=kw)


class MarkInfo:
    """ Marking object created by :class:`MarkDecorator` instances. """
    def __init__(self, name, args, kwargs):
        #: name of attribute
        self.name = name
        #: positional argument list, empty if none specified
        self.args = args
        #: keyword argument dictionary, empty if nothing specified
        self.kwargs = kwargs.copy()
        self._arglist = [(args, kwargs.copy())]

    def __repr__(self):
        return "<MarkInfo %r args=%r kwargs=%r>" % (
            self.name, self.args, self.kwargs
        )

    def add(self, args, kwargs):
        """ add a MarkInfo with the given args and kwargs. """
        self._arglist.append((args, kwargs))
        self.args += args
        self.kwargs.update(kwargs)

    def __iter__(self):
        """ yield MarkInfo objects each relating to a marking-call. """
        for args, kwargs in self._arglist:
            yield MarkInfo(self.name, args, kwargs)
