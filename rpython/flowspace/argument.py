"""
Arguments objects.
"""
from rpython.flowspace.model import const

class Signature(object):
    _immutable_ = True
    _immutable_fields_ = ["argnames[*]"]
    __slots__ = ("argnames", "varargname", "kwargname")

    def __init__(self, argnames, varargname=None, kwargname=None):
        self.argnames = argnames
        self.varargname = varargname
        self.kwargname = kwargname

    def find_argname(self, name):
        try:
            return self.argnames.index(name)
        except ValueError:
            return -1

    def num_argnames(self):
        return len(self.argnames)

    def has_vararg(self):
        return self.varargname is not None

    def has_kwarg(self):
        return self.kwargname is not None

    def scope_length(self):
        scopelen = len(self.argnames)
        scopelen += self.has_vararg()
        scopelen += self.has_kwarg()
        return scopelen

    def getallvarnames(self):
        argnames = self.argnames
        if self.varargname is not None:
            argnames = argnames + [self.varargname]
        if self.kwargname is not None:
            argnames = argnames + [self.kwargname]
        return argnames

    def __repr__(self):
        return "Signature(%r, %r, %r)" % (
                self.argnames, self.varargname, self.kwargname)

    def __eq__(self, other):
        if not isinstance(other, Signature):
            return NotImplemented
        return (self.argnames == other.argnames and
                self.varargname == other.varargname and
                self.kwargname == other.kwargname)

    def __ne__(self, other):
        if not isinstance(other, Signature):
            return NotImplemented
        return not self == other

    # make it look tuply for its use in the annotator

    def __len__(self):
        return 3

    def __getitem__(self, i):
        if i == 0:
            return self.argnames
        if i == 1:
            return self.varargname
        if i == 2:
            return self.kwargname
        raise IndexError


class CallSpec(object):
    """Represents the arguments passed into a function call, i.e. the
    `a, b, *c, **d` part in `return func(a, b, *c, **d)`.
    """
    def __init__(self, args_w, keywords=None, w_stararg=None):
        self.w_stararg = w_stararg
        assert isinstance(args_w, list)
        self.arguments_w = args_w
        self.keywords = keywords or {}

    def __repr__(self):
        """ NOT_RPYTHON """
        name = self.__class__.__name__
        if not self.keywords:
            return '%s(%s)' % (name, self.arguments_w,)
        else:
            return '%s(%s, %s)' % (name, self.arguments_w, self.keywords)

    def flatten(self):
        """ Argument <-> list of w_objects together with "shape" information """
        shape_cnt, shape_keys, shape_star = self._rawshape()
        data_w = self.arguments_w + [self.keywords[key] for key in shape_keys]
        if shape_star:
            data_w.append(self.w_stararg)
        return (shape_cnt, shape_keys, shape_star), data_w

    def _rawshape(self):
        shape_cnt = len(self.arguments_w)
        shape_keys = tuple(sorted(self.keywords))
        shape_star = self.w_stararg is not None   # Flag: presence of *arg
        return shape_cnt, shape_keys, shape_star

    def as_list(self):
        assert not self.keywords
        if self.w_stararg is None:
            return self.arguments_w
        else:
            return self.arguments_w + [const(x) for x in self.w_stararg.value]

    @classmethod
    def fromshape(cls, (shape_cnt, shape_keys, shape_star), data_w):
        args_w = data_w[:shape_cnt]
        p = end_keys = shape_cnt + len(shape_keys)
        if shape_star:
            w_star = data_w[p]
            p += 1
        else:
            w_star = None
        return cls(args_w, dict(zip(shape_keys, data_w[shape_cnt:end_keys])),
                w_star)

