from rpython.rlib import jit

class Signature(object):
    _immutable_ = True
    _immutable_fields_ = ["argnames[*]"]
    __slots__ = ("argnames", "posonlyargcount", "kwonlyargcount", "varargname", "kwargname")

    def __init__(self, argnames, varargname=None, kwargname=None, kwonlyargcount=0, posonlyargcount=0):
        # argnames contains both the positional only as well as the positional
        # arguments. the number of positional only arguments is posonlyargcount
        self.argnames = argnames
        self.varargname = varargname
        self.kwargname = kwargname
        self.posonlyargcount = posonlyargcount
        self.kwonlyargcount = kwonlyargcount
        assert isinstance(kwonlyargcount, int)

    @jit.elidable
    def find_argname(self, name):
        try:
            return self.argnames.index(name)
        except ValueError:
            pass
        return -1

    @jit.elidable
    def find_w_argname(self, w_name):
        for i, name in enumerate(self.argnames):
            if w_name.eq_unwrapped(name):
                return i
        return -1

    def num_argnames(self):
        return len(self.argnames) - self.kwonlyargcount

    def num_posonlyargnames(self):
        return self.posonlyargcount

    def num_kwonlyargnames(self):
        return self.kwonlyargcount

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
        return "Signature(%r, %r, %r, %r, %r)" % (
                self.argnames, self.varargname, self.kwargname, self.kwonlyargcount, self.posonlyargcount)

    def __eq__(self, other):
        if not isinstance(other, Signature):
            return NotImplemented
        return (self.argnames == other.argnames and
                self.varargname == other.varargname and
                self.kwargname == other.kwargname and
                self.posonlyargcount == other.posonlyargcount and
                self.kwonlyargcount == other.kwonlyargcount)

    def __ne__(self, other):
        if not isinstance(other, Signature):
            return NotImplemented
        return not self == other
