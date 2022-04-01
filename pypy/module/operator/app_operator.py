'''NOT_RPYTHON: because of attrgetter and itemgetter
Operator interface.

This module exports a set of operators as functions. E.g. operator.add(x,y) is
equivalent to x+y.
'''


def countOf(a,b):
    'countOf(a, b) -- Return the number of times b occurs in a.'
    count = 0
    for x in a:
        if x is b or x == b:
            count += 1
    return count

def _resolve_attr_chain(chain, obj, idx=0):
    obj = getattr(obj, chain[idx])
    if idx + 1 == len(chain):
        return obj
    else:
        return _resolve_attr_chain(chain, obj, idx + 1)

class attrgetter(object):
    def __init__(self, attr, *attrs):
        if (
            not isinstance(attr, str) or
            not all(isinstance(a, str) for a in attrs)
        ):
            raise TypeError("attribute name must be a string, not %r" %
                        type(attr).__name__)
        elif attrs:
            self._multi_attrs = [
                a.split(".") for a in [attr] + list(attrs)
            ]
            self._call = self._multi_attrgetter
        elif "." not in attr:
            self._simple_attr = attr
            self._call = self._simple_attrgetter
        else:
            self._single_attr = attr.split(".")
            self._call = self._single_attrgetter

    def __call__(self, obj):
        return self._call(obj)

    def _simple_attrgetter(self, obj):
        return getattr(obj, self._simple_attr)

    def _single_attrgetter(self, obj):
        return _resolve_attr_chain(self._single_attr, obj)

    def _multi_attrgetter(self, obj):
        return tuple([
            _resolve_attr_chain(attrs, obj)
            for attrs in self._multi_attrs
        ])

    def __repr__(self):
        try:
            a = repr(self._simple_attr)
        except AttributeError:
            try:
                a = repr('.'.join(self._single_attr))
            except AttributeError:
                lst = self._multi_attrs
                a = ', '.join([repr('.'.join(a1)) for a1 in lst])
        return 'operator.attrgetter(%s)' % (a,)


class itemgetter(object):
    def __init__(self, item, *items):
        self._single = not bool(items)
        if self._single:
            self._idx = item
        else:
            self._idx = [item] + list(items)

    def __call__(self, obj):
        if self._single:
            return obj[self._idx]
        else:
            return tuple([obj[i] for i in self._idx])

    def __repr__(self):
        if self._single:
            a = repr(self._idx)
        else:
            a = ', '.join([repr(i) for i in self._idx])
        return 'operator.itemgetter(%s)' % (a,)


class methodcaller(object):
    def __init__(*args, **kwargs):
        if len(args) < 2:
            raise TypeError("methodcaller() called with not enough arguments")
        self, method_name = args[:2]
        if not isinstance(method_name, str):
            raise TypeError("method name must be a string")
        self._method_name = method_name
        self._args = args[2:]
        self._kwargs = kwargs

    def __call__(self, obj):
        return getattr(obj, self._method_name)(*self._args, **self._kwargs)

    def __repr__(self):
        args = [repr(self._method_name)]
        for a in self._args:
            args.append(repr(a))
        for key, value in self._kwargs.items():
            args.append('%s=%r' % (key, value))
        return 'operator.methodcaller(%s)' % (', '.join(args),)
