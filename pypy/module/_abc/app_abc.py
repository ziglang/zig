# NOT_RPYTHON
"""
Plain Python definition of the builtin ABC-related functions.
"""

# Cannot use _weakrefset like in _py_abc.py, since it is not a built-in module
from _weakref import ref

# We'll make our own WeakSet instead, with only the functionality that's needed
# This replaces the easily-forgetable calls to '_add_to_weak_set' and
# '_in_weak_set' from the CPython implementation
class SimpleWeakSet:
    def __init__(self, data=None):
        self.data = set()
        def _remove(item, selfref=ref(self)):
            self = selfref()
            if self is not None:
                self.data.discard(item)
        self._remove = _remove

    def __iter__(self):
        # Weakref callback may remove entry from set.
        # So we make a copy first.
        copy = list(self.data)
        for itemref in copy:
            item = itemref()
            if item is not None:
                yield item

    def __contains__(self, item):
        try:
            wr = ref(item)
        except TypeError:
            return False
        return wr in self.data

    def add(self, item):
        self.data.add(ref(item, self._remove))

    def clear(self):
        self.data.clear()


abc_invalidation_counter = 0


def get_cache_token():
    """Returns the current ABC cache token.

    The token is an opaque object (supporting equality testing) identifying the
    current version of the ABC cache for virtual subclasses. The token changes
    with every call to ``register()`` on any ABC.
    """
    return abc_invalidation_counter


def _abc_init(cls):
    """Internal ABC helper for class set-up. Should be never used outside abc module."""
    namespace = cls.__dict__
    abstracts = {name
                for name, value in namespace.items()
                if getattr(value, "__isabstractmethod__", False)}
    bases = cls.__bases__
    for base in bases:
        for name in getattr(base, "__abstractmethods__", set()):
            value = getattr(cls, name, None)
            if getattr(value, "__isabstractmethod__", False):
                abstracts.add(name)
    cls.__abstractmethods__ = frozenset(abstracts)
    # Set up inheritance registry
    cls._abc_registry = SimpleWeakSet()
    cls._abc_cache = SimpleWeakSet()
    cls._abc_negative_cache = SimpleWeakSet()
    cls._abc_negative_cache_version = abc_invalidation_counter


def _abc_register(cls, subclass):
    """Internal ABC helper for subclasss registration. Should be never used outside abc module."""
    if not isinstance(subclass, type):
        raise TypeError("Can only register classes")
    if issubclass(subclass, cls):
        return subclass  # Already a subclass
    # Subtle: test for cycles *after* testing for "already a subclass";
    # this means we allow X.register(X) and interpret it as a no-op.
    if issubclass(cls, subclass):
        # This would create a cycle, which is bad for the algorithm below
        raise RuntimeError("Refusing to create an inheritance cycle")
    cls._abc_registry.add(subclass)
    global abc_invalidation_counter
    abc_invalidation_counter += 1  # Invalidate negative cache
    return subclass


def _abc_instancecheck(cls, instance):
    """Internal ABC helper for instance checks. Should be never used outside abc module."""
    # Inline the cache checking
    subclass = instance.__class__
    if subclass in cls._abc_cache:
        return True
    subtype = type(instance)
    if subtype is subclass:
        if (cls._abc_negative_cache_version == abc_invalidation_counter and
            subclass in cls._abc_negative_cache):
            return False
        # Fall back to the subclass check.
        return cls.__subclasscheck__(subclass)
    return any(cls.__subclasscheck__(c) for c in (subclass, subtype))


def _abc_subclasscheck(cls, subclass):
    """Internal ABC helper for subclasss checks. Should be never used outside abc module."""
    if not isinstance(subclass, type):
        raise TypeError('issubclass() arg 1 must be a class')
    # Check cache
    if subclass in cls._abc_cache:
        return True
    # Check negative cache; may have to invalidate
    if cls._abc_negative_cache_version < abc_invalidation_counter:
        # Invalidate the negative cache
        cls._abc_negative_cache = SimpleWeakSet()
        cls._abc_negative_cache_version = abc_invalidation_counter
    elif subclass in cls._abc_negative_cache:
        return False
    # Check the subclass hook
    ok = cls.__subclasshook__(subclass)
    if ok is not NotImplemented:
        assert isinstance(ok, bool)
        if ok:
            cls._abc_cache.add(subclass)
        else:
            cls._abc_negative_cache.add(subclass)
        return ok
    # Check if it's a direct subclass
    if cls in getattr(subclass, '__mro__', ()):
        cls._abc_cache.add(subclass)
        return True
    # Check if it's a subclass of a registered class (recursive)
    for rcls in cls._abc_registry:
        if issubclass(subclass, rcls):
            cls._abc_cache.add(subclass)
            return True
    # Check if it's a subclass of a subclass (recursive)
    for scls in cls.__subclasses__():
        if issubclass(subclass, scls):
            cls._abc_cache.add(subclass)
            return True
    # No dice; update negative cache
    cls._abc_negative_cache.add(subclass)
    return False


def _get_dump(cls):
    """Internal ABC helper for cache and registry debugging

    Return shallow copies of registry, of both caches, and
    negative cache version. Don't call this function directly,
    instead use ABC._dump_registry() for a nice repr."""
    return (cls._abc_registry.data,
            cls._abc_cache.data,
            cls._abc_negative_cache.data,
            cls._abc_negative_cache_version)


def _reset_registry(cls):
    """Internal ABC helper to reset registry of a given class.

    Should be only used by refleak.py"""
    cls._abc_registry.clear()


def _reset_caches(cls):
    """Internal ABC helper to reset both caches of a given class.

    Should be only used by refleak.py"""
    cls._abc_cache.clear()
    cls._abc_negative_cache.clear()
