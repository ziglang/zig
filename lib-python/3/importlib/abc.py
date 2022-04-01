"""Abstract base classes related to import."""
from . import _bootstrap
from . import _bootstrap_external
from . import machinery
try:
    import _frozen_importlib
except ImportError as exc:
    if exc.name != '_frozen_importlib':
        raise
    _frozen_importlib = None
try:
    import _frozen_importlib_external
except ImportError:
    _frozen_importlib_external = _bootstrap_external
import abc
import warnings
from typing import Protocol, runtime_checkable


def _register(abstract_cls, *classes):
    for cls in classes:
        abstract_cls.register(cls)
        if _frozen_importlib is not None:
            try:
                frozen_cls = getattr(_frozen_importlib, cls.__name__)
            except AttributeError:
                frozen_cls = getattr(_frozen_importlib_external, cls.__name__)
            abstract_cls.register(frozen_cls)


class Finder(metaclass=abc.ABCMeta):

    """Legacy abstract base class for import finders.

    It may be subclassed for compatibility with legacy third party
    reimplementations of the import system.  Otherwise, finder
    implementations should derive from the more specific MetaPathFinder
    or PathEntryFinder ABCs.

    Deprecated since Python 3.3
    """

    @abc.abstractmethod
    def find_module(self, fullname, path=None):
        """An abstract method that should find a module.
        The fullname is a str and the optional path is a str or None.
        Returns a Loader object or None.
        """


class MetaPathFinder(Finder):

    """Abstract base class for import finders on sys.meta_path."""

    # We don't define find_spec() here since that would break
    # hasattr checks we do to support backward compatibility.

    def find_module(self, fullname, path):
        """Return a loader for the module.

        If no module is found, return None.  The fullname is a str and
        the path is a list of strings or None.

        This method is deprecated since Python 3.4 in favor of
        finder.find_spec(). If find_spec() exists then backwards-compatible
        functionality is provided for this method.

        """
        warnings.warn("MetaPathFinder.find_module() is deprecated since Python "
                      "3.4 in favor of MetaPathFinder.find_spec() "
                      "(available since 3.4)",
                      DeprecationWarning,
                      stacklevel=2)
        if not hasattr(self, 'find_spec'):
            return None
        found = self.find_spec(fullname, path)
        return found.loader if found is not None else None

    def invalidate_caches(self):
        """An optional method for clearing the finder's cache, if any.
        This method is used by importlib.invalidate_caches().
        """

_register(MetaPathFinder, machinery.BuiltinImporter, machinery.FrozenImporter,
          machinery.PathFinder, machinery.WindowsRegistryFinder)


class PathEntryFinder(Finder):

    """Abstract base class for path entry finders used by PathFinder."""

    # We don't define find_spec() here since that would break
    # hasattr checks we do to support backward compatibility.

    def find_loader(self, fullname):
        """Return (loader, namespace portion) for the path entry.

        The fullname is a str.  The namespace portion is a sequence of
        path entries contributing to part of a namespace package. The
        sequence may be empty.  If loader is not None, the portion will
        be ignored.

        The portion will be discarded if another path entry finder
        locates the module as a normal module or package.

        This method is deprecated since Python 3.4 in favor of
        finder.find_spec(). If find_spec() is provided than backwards-compatible
        functionality is provided.
        """
        warnings.warn("PathEntryFinder.find_loader() is deprecated since Python "
                      "3.4 in favor of PathEntryFinder.find_spec() "
                      "(available since 3.4)",
                      DeprecationWarning,
                      stacklevel=2)
        if not hasattr(self, 'find_spec'):
            return None, []
        found = self.find_spec(fullname)
        if found is not None:
            if not found.submodule_search_locations:
                portions = []
            else:
                portions = found.submodule_search_locations
            return found.loader, portions
        else:
            return None, []

    find_module = _bootstrap_external._find_module_shim

    def invalidate_caches(self):
        """An optional method for clearing the finder's cache, if any.
        This method is used by PathFinder.invalidate_caches().
        """

_register(PathEntryFinder, machinery.FileFinder)


class Loader(metaclass=abc.ABCMeta):

    """Abstract base class for import loaders."""

    def create_module(self, spec):
        """Return a module to initialize and into which to load.

        This method should raise ImportError if anything prevents it
        from creating a new module.  It may return None to indicate
        that the spec should create the new module.
        """
        # By default, defer to default semantics for the new module.
        return None

    # We don't define exec_module() here since that would break
    # hasattr checks we do to support backward compatibility.

    def load_module(self, fullname):
        """Return the loaded module.

        The module must be added to sys.modules and have import-related
        attributes set properly.  The fullname is a str.

        ImportError is raised on failure.

        This method is deprecated in favor of loader.exec_module(). If
        exec_module() exists then it is used to provide a backwards-compatible
        functionality for this method.

        """
        if not hasattr(self, 'exec_module'):
            raise ImportError
        return _bootstrap._load_module_shim(self, fullname)

    def module_repr(self, module):
        """Return a module's repr.

        Used by the module type when the method does not raise
        NotImplementedError.

        This method is deprecated.

        """
        # The exception will cause ModuleType.__repr__ to ignore this method.
        raise NotImplementedError


class ResourceLoader(Loader):

    """Abstract base class for loaders which can return data from their
    back-end storage.

    This ABC represents one of the optional protocols specified by PEP 302.

    """

    @abc.abstractmethod
    def get_data(self, path):
        """Abstract method which when implemented should return the bytes for
        the specified path.  The path must be a str."""
        raise OSError


class InspectLoader(Loader):

    """Abstract base class for loaders which support inspection about the
    modules they can load.

    This ABC represents one of the optional protocols specified by PEP 302.

    """

    def is_package(self, fullname):
        """Optional method which when implemented should return whether the
        module is a package.  The fullname is a str.  Returns a bool.

        Raises ImportError if the module cannot be found.
        """
        raise ImportError

    def get_code(self, fullname):
        """Method which returns the code object for the module.

        The fullname is a str.  Returns a types.CodeType if possible, else
        returns None if a code object does not make sense
        (e.g. built-in module). Raises ImportError if the module cannot be
        found.
        """
        source = self.get_source(fullname)
        if source is None:
            return None
        return self.source_to_code(source)

    @abc.abstractmethod
    def get_source(self, fullname):
        """Abstract method which should return the source code for the
        module.  The fullname is a str.  Returns a str.

        Raises ImportError if the module cannot be found.
        """
        raise ImportError

    @staticmethod
    def source_to_code(data, path='<string>'):
        """Compile 'data' into a code object.

        The 'data' argument can be anything that compile() can handle. The'path'
        argument should be where the data was retrieved (when applicable)."""
        return compile(data, path, 'exec', dont_inherit=True)

    exec_module = _bootstrap_external._LoaderBasics.exec_module
    load_module = _bootstrap_external._LoaderBasics.load_module

_register(InspectLoader, machinery.BuiltinImporter, machinery.FrozenImporter)


class ExecutionLoader(InspectLoader):

    """Abstract base class for loaders that wish to support the execution of
    modules as scripts.

    This ABC represents one of the optional protocols specified in PEP 302.

    """

    @abc.abstractmethod
    def get_filename(self, fullname):
        """Abstract method which should return the value that __file__ is to be
        set to.

        Raises ImportError if the module cannot be found.
        """
        raise ImportError

    def get_code(self, fullname):
        """Method to return the code object for fullname.

        Should return None if not applicable (e.g. built-in module).
        Raise ImportError if the module cannot be found.
        """
        source = self.get_source(fullname)
        if source is None:
            return None
        try:
            path = self.get_filename(fullname)
        except ImportError:
            return self.source_to_code(source)
        else:
            return self.source_to_code(source, path)

_register(ExecutionLoader, machinery.ExtensionFileLoader)


class FileLoader(_bootstrap_external.FileLoader, ResourceLoader, ExecutionLoader):

    """Abstract base class partially implementing the ResourceLoader and
    ExecutionLoader ABCs."""

_register(FileLoader, machinery.SourceFileLoader,
            machinery.SourcelessFileLoader)


class SourceLoader(_bootstrap_external.SourceLoader, ResourceLoader, ExecutionLoader):

    """Abstract base class for loading source code (and optionally any
    corresponding bytecode).

    To support loading from source code, the abstractmethods inherited from
    ResourceLoader and ExecutionLoader need to be implemented. To also support
    loading from bytecode, the optional methods specified directly by this ABC
    is required.

    Inherited abstractmethods not implemented in this ABC:

        * ResourceLoader.get_data
        * ExecutionLoader.get_filename

    """

    def path_mtime(self, path):
        """Return the (int) modification time for the path (str)."""
        if self.path_stats.__func__ is SourceLoader.path_stats:
            raise OSError
        return int(self.path_stats(path)['mtime'])

    def path_stats(self, path):
        """Return a metadata dict for the source pointed to by the path (str).
        Possible keys:
        - 'mtime' (mandatory) is the numeric timestamp of last source
          code modification;
        - 'size' (optional) is the size in bytes of the source code.
        """
        if self.path_mtime.__func__ is SourceLoader.path_mtime:
            raise OSError
        return {'mtime': self.path_mtime(path)}

    def set_data(self, path, data):
        """Write the bytes to the path (if possible).

        Accepts a str path and data as bytes.

        Any needed intermediary directories are to be created. If for some
        reason the file cannot be written because of permissions, fail
        silently.
        """

_register(SourceLoader, machinery.SourceFileLoader)


class ResourceReader(metaclass=abc.ABCMeta):

    """Abstract base class to provide resource-reading support.

    Loaders that support resource reading are expected to implement
    the ``get_resource_reader(fullname)`` method and have it either return None
    or an object compatible with this ABC.
    """

    @abc.abstractmethod
    def open_resource(self, resource):
        """Return an opened, file-like object for binary reading.

        The 'resource' argument is expected to represent only a file name
        and thus not contain any subdirectory components.

        If the resource cannot be found, FileNotFoundError is raised.
        """
        raise FileNotFoundError

    @abc.abstractmethod
    def resource_path(self, resource):
        """Return the file system path to the specified resource.

        The 'resource' argument is expected to represent only a file name
        and thus not contain any subdirectory components.

        If the resource does not exist on the file system, raise
        FileNotFoundError.
        """
        raise FileNotFoundError

    @abc.abstractmethod
    def is_resource(self, name):
        """Return True if the named 'name' is consider a resource."""
        raise FileNotFoundError

    @abc.abstractmethod
    def contents(self):
        """Return an iterable of strings over the contents of the package."""
        return []


_register(ResourceReader, machinery.SourceFileLoader)


@runtime_checkable
class Traversable(Protocol):
    """
    An object with a subset of pathlib.Path methods suitable for
    traversing directories and opening files.
    """

    @abc.abstractmethod
    def iterdir(self):
        """
        Yield Traversable objects in self
        """

    @abc.abstractmethod
    def read_bytes(self):
        """
        Read contents of self as bytes
        """

    @abc.abstractmethod
    def read_text(self, encoding=None):
        """
        Read contents of self as bytes
        """

    @abc.abstractmethod
    def is_dir(self):
        """
        Return True if self is a dir
        """

    @abc.abstractmethod
    def is_file(self):
        """
        Return True if self is a file
        """

    @abc.abstractmethod
    def joinpath(self, child):
        """
        Return Traversable child in self
        """

    @abc.abstractmethod
    def __truediv__(self, child):
        """
        Return Traversable child in self
        """

    @abc.abstractmethod
    def open(self, mode='r', *args, **kwargs):
        """
        mode may be 'r' or 'rb' to open as text or binary. Return a handle
        suitable for reading (same as pathlib.Path.open).

        When opening as text, accepts encoding parameters such as those
        accepted by io.TextIOWrapper.
        """

    @abc.abstractproperty
    def name(self):
        # type: () -> str
        """
        The base name of this object without any parent references.
        """


class TraversableResources(ResourceReader):
    @abc.abstractmethod
    def files(self):
        """Return a Traversable object for the loaded package."""

    def open_resource(self, resource):
        return self.files().joinpath(resource).open('rb')

    def resource_path(self, resource):
        raise FileNotFoundError(resource)

    def is_resource(self, path):
        return self.files().joinpath(path).isfile()

    def contents(self):
        return (item.name for item in self.files().iterdir())
