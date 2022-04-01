from __pypy__ import get_contextvar_context, set_contextvar_context
from _immutables_map import Map
from _pypy_generic_alias import GenericAlias
# implementation taken from PEP-0567 https://www.python.org/dev/peps/pep-0567/

_NO_DEFAULT = object()


class Unsubclassable(type):
    def __new__(cls, name, bases, dct):
        for base in bases:
            if isinstance(base, Unsubclassable):
                raise TypeError(f"type '{base.__name__}' is not an acceptable base type")
        return type.__new__(cls, name, bases, dict(dct))


def get_context():
    context = get_contextvar_context()
    if context is None:
        context = Context()
        set_contextvar_context(context)
    return context


class Context(metaclass=Unsubclassable):

    #_data: Map
    #_is_entered: bool

    def __init__(self):
        self._data = Map()
        self._is_entered = False

    def run(self, callable, *args, **kwargs):
        if self._is_entered:
            raise RuntimeError(
                f'cannot enter context: {self} is already entered')

        # don't use get_context() here, to avoid creating a Context object
        _prev_context = get_contextvar_context()
        try:
            self._is_entered = True
            set_contextvar_context(self)
            return callable(*args, **kwargs)
        finally:
            set_contextvar_context(_prev_context)
            self._is_entered = False

    def copy(self):
        new = Context()
        new._data = self._data
        return new

    # Implement abstract Mapping.__getitem__
    def __getitem__(self, var):
        if not isinstance(var, ContextVar):
            raise TypeError("ContextVar key was expected")
        return self._data[var]

    # Implement abstract Mapping.__contains__
    def __contains__(self, var):
        if not isinstance(var, ContextVar):
            raise TypeError("ContextVar key was expected")
        return var in self._data

    # Implement abstract Mapping.__len__
    def __len__(self):
        return len(self._data)

    # Implement abstract Mapping.__iter__
    def __iter__(self):
        return iter(self._data)

    def get(self, key, default=None):
        if not isinstance(key, ContextVar):
            raise TypeError("ContextVar key was expected")
        try:
            return self._data[key]
        except KeyError:
            return default

    def keys(self):
        from collections.abc import KeysView
        return KeysView(self)

    def values(self):
        from collections.abc import ValuesView
        return ValuesView(self)

    def items(self):
        from collections.abc import ItemsView
        return ItemsView(self)

    def __eq__(self, other):
        if not isinstance(other, Context):
            return NotImplemented
        return dict(self.items()) == dict(other.items())


def copy_context():
    return get_context().copy()

class ContextVar(metaclass=Unsubclassable):

    def __init__(self, name, *, default=_NO_DEFAULT):
        if not isinstance(name, str):
            raise TypeError("context variable name must be a str")
        self._name = name
        self._default = default

    @property
    def name(self):
        return self._name

    def get(self, default=_NO_DEFAULT):
        # don't use get_context() here, to avoid creating a Context object
        context = get_contextvar_context()
        if context is not None:
            try:
                return context[self]
            except KeyError:
                pass

        if default is not _NO_DEFAULT:
            return default

        if self._default is not _NO_DEFAULT:
            return self._default

        raise LookupError

    def set(self, value):
        context = get_context()

        data: Map = context._data
        try:
            old_value = data[self]
        except KeyError:
            old_value = Token.MISSING

        updated_data = data.set(self, value)
        context._data = updated_data
        return Token(context, self, old_value)

    def reset(self, token):
        if token._used:
            raise RuntimeError("Token has already been used once")

        if token._var is not self:
            raise ValueError(
                "Token was created by a different ContextVar")

        context = get_context()
        if token._context is not context:
            raise ValueError(
                "Token was created in a different Context")

        if token._old_value is Token.MISSING:
            context._data = context._data.delete(token._var)
        else:
            context._data = context._data.set(token._var, token._old_value)

        token._used = True

    @classmethod
    def __class_getitem__(self, key):
        return self

    def __repr__(self):
        default = ''
        if self._default is not _NO_DEFAULT:
            default = f"default={self._default} "
        return f"<ContextVar name={self.name!r} {default}at 0x{id(self):x}>"


class Token(metaclass=Unsubclassable):
    MISSING = object()

    def __init__(self, context, var, old_value):
        self._context = context
        self._var = var
        self._old_value = old_value
        self._used = False

    @property
    def var(self):
        return self._var

    @property
    def old_value(self):
        return self._old_value

    def __repr__(self):
        return f"<Token {'used ' if self._used else ''}var={self._var} at 0x{id(self):x}>"

    def __class_getitem__(self, item):
        return GenericAlias(self, item)
