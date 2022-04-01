import _csv

class Error(Exception):
    pass


_dialects = {}

def register_dialect(name, dialect=None, **kwargs):
    """Create a mapping from a string name to a dialect class."""
    if not isinstance(name, str):
        raise TypeError("dialect name must be a string or unicode")

    dialect = _csv.Dialect(dialect, **kwargs)
    _dialects[name] = dialect

def unregister_dialect(name):
    """Delete the name/dialect mapping associated with a string name."""
    try:
        del _dialects[name]
    except KeyError:
        raise Error("unknown dialect")

def get_dialect(name):
    """Return the dialect instance associated with name."""
    try:
        return _dialects[name]
    except KeyError:
        raise Error("unknown dialect")

def list_dialects():
    """Return a list of all know dialect names."""
    return list(_dialects)
