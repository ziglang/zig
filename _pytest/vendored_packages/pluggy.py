"""
PluginManager, basic initialization and tracing.

pluggy is the cristallized core of plugin management as used
by some 150 plugins for pytest.

Pluggy uses semantic versioning. Breaking changes are only foreseen for
Major releases (incremented X in "X.Y.Z").  If you want to use pluggy in
your project you should thus use a dependency restriction like
"pluggy>=0.1.0,<1.0" to avoid surprises.

pluggy is concerned with hook specification, hook implementations and hook
calling.  For any given hook specification a hook call invokes up to N implementations.
A hook implementation can influence its position and type of execution:
if attributed "tryfirst" or "trylast" it will be tried to execute
first or last.  However, if attributed "hookwrapper" an implementation
can wrap all calls to non-hookwrapper implementations.  A hookwrapper
can thus execute some code ahead and after the execution of other hooks.

Hook specification is done by way of a regular python function where
both the function name and the names of all its arguments are significant.
Each hook implementation function is verified against the original specification
function, including the names of all its arguments.  To allow for hook specifications
to evolve over the livetime of a project, hook implementations can
accept less arguments.  One can thus add new arguments and semantics to
a hook specification by adding another argument typically without breaking
existing hook implementations.

The chosen approach is meant to let a hook designer think carefuly about
which objects are needed by an extension writer.  By contrast, subclass-based
extension mechanisms often expose a lot more state and behaviour than needed,
thus restricting future developments.

Pluggy currently consists of functionality for:

- a way to register new hook specifications.  Without a hook
  specification no hook calling can be performed.

- a registry of plugins which contain hook implementation functions.  It
  is possible to register plugins for which a hook specification is not yet
  known and validate all hooks when the system is in a more referentially
  consistent state.  Setting an "optionalhook" attribution to a hook
  implementation will avoid PluginValidationError's if a specification
  is missing.  This allows to have optional integration between plugins.

- a "hook" relay object from which you can launch 1:N calls to
  registered hook implementation functions

- a mechanism for ordering hook implementation functions

- mechanisms for two different type of 1:N calls: "firstresult" for when
  the call should stop when the first implementation returns a non-None result.
  And the other (default) way of guaranteeing that all hook implementations
  will be called and their non-None result collected.

- mechanisms for "historic" extension points such that all newly
  registered functions will receive all hook calls that happened
  before their registration.

- a mechanism for discovering plugin objects which are based on
  setuptools based entry points.

- a simple tracing mechanism, including tracing of plugin calls and
  their arguments.

"""
import sys
import inspect

__version__ = '0.3.1'
__all__ = ["PluginManager", "PluginValidationError",
           "HookspecMarker", "HookimplMarker"]

_py3 = sys.version_info > (3, 0)


class HookspecMarker:
    """ Decorator helper class for marking functions as hook specifications.

    You can instantiate it with a project_name to get a decorator.
    Calling PluginManager.add_hookspecs later will discover all marked functions
    if the PluginManager uses the same project_name.
    """

    def __init__(self, project_name):
        self.project_name = project_name

    def __call__(self, function=None, firstresult=False, historic=False):
        """ if passed a function, directly sets attributes on the function
        which will make it discoverable to add_hookspecs().  If passed no
        function, returns a decorator which can be applied to a function
        later using the attributes supplied.

        If firstresult is True the 1:N hook call (N being the number of registered
        hook implementation functions) will stop at I<=N when the I'th function
        returns a non-None result.

        If historic is True calls to a hook will be memorized and replayed
        on later registered plugins.

        """
        def setattr_hookspec_opts(func):
            if historic and firstresult:
                raise ValueError("cannot have a historic firstresult hook")
            setattr(func, self.project_name + "_spec",
                   dict(firstresult=firstresult, historic=historic))
            return func

        if function is not None:
            return setattr_hookspec_opts(function)
        else:
            return setattr_hookspec_opts


class HookimplMarker:
    """ Decorator helper class for marking functions as hook implementations.

    You can instantiate with a project_name to get a decorator.
    Calling PluginManager.register later will discover all marked functions
    if the PluginManager uses the same project_name.
    """
    def __init__(self, project_name):
        self.project_name = project_name

    def __call__(self, function=None, hookwrapper=False, optionalhook=False,
                 tryfirst=False, trylast=False):

        """ if passed a function, directly sets attributes on the function
        which will make it discoverable to register().  If passed no function,
        returns a decorator which can be applied to a function later using
        the attributes supplied.

        If optionalhook is True a missing matching hook specification will not result
        in an error (by default it is an error if no matching spec is found).

        If tryfirst is True this hook implementation will run as early as possible
        in the chain of N hook implementations for a specfication.

        If trylast is True this hook implementation will run as late as possible
        in the chain of N hook implementations.

        If hookwrapper is True the hook implementations needs to execute exactly
        one "yield".  The code before the yield is run early before any non-hookwrapper
        function is run.  The code after the yield is run after all non-hookwrapper
        function have run.  The yield receives an ``_CallOutcome`` object representing
        the exception or result outcome of the inner calls (including other hookwrapper
        calls).

        """
        def setattr_hookimpl_opts(func):
            setattr(func, self.project_name + "_impl",
                   dict(hookwrapper=hookwrapper, optionalhook=optionalhook,
                        tryfirst=tryfirst, trylast=trylast))
            return func

        if function is None:
            return setattr_hookimpl_opts
        else:
            return setattr_hookimpl_opts(function)


def normalize_hookimpl_opts(opts):
    opts.setdefault("tryfirst", False)
    opts.setdefault("trylast", False)
    opts.setdefault("hookwrapper", False)
    opts.setdefault("optionalhook", False)


class _TagTracer:
    def __init__(self):
        self._tag2proc = {}
        self.writer = None
        self.indent = 0

    def get(self, name):
        return _TagTracerSub(self, (name,))

    def format_message(self, tags, args):
        if isinstance(args[-1], dict):
            extra = args[-1]
            args = args[:-1]
        else:
            extra = {}

        content = " ".join(map(str, args))
        indent = "  " * self.indent

        lines = [
            "%s%s [%s]\n" % (indent, content, ":".join(tags))
        ]

        for name, value in extra.items():
            lines.append("%s    %s: %s\n" % (indent, name, value))
        return lines

    def processmessage(self, tags, args):
        if self.writer is not None and args:
            lines = self.format_message(tags, args)
            self.writer(''.join(lines))
        try:
            self._tag2proc[tags](tags, args)
        except KeyError:
            pass

    def setwriter(self, writer):
        self.writer = writer

    def setprocessor(self, tags, processor):
        if isinstance(tags, str):
            tags = tuple(tags.split(":"))
        else:
            assert isinstance(tags, tuple)
        self._tag2proc[tags] = processor


class _TagTracerSub:
    def __init__(self, root, tags):
        self.root = root
        self.tags = tags

    def __call__(self, *args):
        self.root.processmessage(self.tags, args)

    def setmyprocessor(self, processor):
        self.root.setprocessor(self.tags, processor)

    def get(self, name):
        return self.__class__(self.root, self.tags + (name,))


def _raise_wrapfail(wrap_controller, msg):
    co = wrap_controller.gi_code
    raise RuntimeError("wrap_controller at %r %s:%d %s" %
                   (co.co_name, co.co_filename, co.co_firstlineno, msg))


def _wrapped_call(wrap_controller, func):
    """ Wrap calling to a function with a generator which needs to yield
    exactly once.  The yield point will trigger calling the wrapped function
    and return its _CallOutcome to the yield point.  The generator then needs
    to finish (raise StopIteration) in order for the wrapped call to complete.
    """
    try:
        next(wrap_controller)   # first yield
    except StopIteration:
        _raise_wrapfail(wrap_controller, "did not yield")
    call_outcome = _CallOutcome(func)
    try:
        wrap_controller.send(call_outcome)
        _raise_wrapfail(wrap_controller, "has second yield")
    except StopIteration:
        pass
    return call_outcome.get_result()


class _CallOutcome:
    """ Outcome of a function call, either an exception or a proper result.
    Calling the ``get_result`` method will return the result or reraise
    the exception raised when the function was called. """
    excinfo = None

    def __init__(self, func):
        try:
            self.result = func()
        except BaseException:
            self.excinfo = sys.exc_info()

    def force_result(self, result):
        self.result = result
        self.excinfo = None

    def get_result(self):
        if self.excinfo is None:
            return self.result
        else:
            ex = self.excinfo
            if _py3:
                raise ex[1].with_traceback(ex[2])
            _reraise(*ex)  # noqa

if not _py3:
    exec("""
def _reraise(cls, val, tb):
    raise cls, val, tb
""")


class _TracedHookExecution:
    def __init__(self, pluginmanager, before, after):
        self.pluginmanager = pluginmanager
        self.before = before
        self.after = after
        self.oldcall = pluginmanager._inner_hookexec
        assert not isinstance(self.oldcall, _TracedHookExecution)
        self.pluginmanager._inner_hookexec = self

    def __call__(self, hook, hook_impls, kwargs):
        self.before(hook.name, hook_impls, kwargs)
        outcome = _CallOutcome(lambda: self.oldcall(hook, hook_impls, kwargs))
        self.after(outcome, hook.name, hook_impls, kwargs)
        return outcome.get_result()

    def undo(self):
        self.pluginmanager._inner_hookexec = self.oldcall


class PluginManager(object):
    """ Core Pluginmanager class which manages registration
    of plugin objects and 1:N hook calling.

    You can register new hooks by calling ``addhooks(module_or_class)``.
    You can register plugin objects (which contain hooks) by calling
    ``register(plugin)``.  The Pluginmanager is initialized with a
    prefix that is searched for in the names of the dict of registered
    plugin objects.  An optional excludefunc allows to blacklist names which
    are not considered as hooks despite a matching prefix.

    For debugging purposes you can call ``enable_tracing()``
    which will subsequently send debug information to the trace helper.
    """

    def __init__(self, project_name, implprefix=None):
        """ if implprefix is given implementation functions
        will be recognized if their name matches the implprefix. """
        self.project_name = project_name
        self._name2plugin = {}
        self._plugin2hookcallers = {}
        self._plugin_distinfo = []
        self.trace = _TagTracer().get("pluginmanage")
        self.hook = _HookRelay(self.trace.root.get("hook"))
        self._implprefix = implprefix
        self._inner_hookexec = lambda hook, methods, kwargs: \
            _MultiCall(methods, kwargs, hook.spec_opts).execute()

    def _hookexec(self, hook, methods, kwargs):
        # called from all hookcaller instances.
        # enable_tracing will set its own wrapping function at self._inner_hookexec
        return self._inner_hookexec(hook, methods, kwargs)

    def register(self, plugin, name=None):
        """ Register a plugin and return its canonical name or None if the name
        is blocked from registering.  Raise a ValueError if the plugin is already
        registered. """
        plugin_name = name or self.get_canonical_name(plugin)

        if plugin_name in self._name2plugin or plugin in self._plugin2hookcallers:
            if self._name2plugin.get(plugin_name, -1) is None:
                return  # blocked plugin, return None to indicate no registration
            raise ValueError("Plugin already registered: %s=%s\n%s" %
                            (plugin_name, plugin, self._name2plugin))

        # XXX if an error happens we should make sure no state has been
        # changed at point of return
        self._name2plugin[plugin_name] = plugin

        # register matching hook implementations of the plugin
        self._plugin2hookcallers[plugin] = hookcallers = []
        for name in dir(plugin):
            hookimpl_opts = self.parse_hookimpl_opts(plugin, name)
            if hookimpl_opts is not None:
                normalize_hookimpl_opts(hookimpl_opts)
                method = getattr(plugin, name)
                hookimpl = HookImpl(plugin, plugin_name, method, hookimpl_opts)
                hook = getattr(self.hook, name, None)
                if hook is None:
                    hook = _HookCaller(name, self._hookexec)
                    setattr(self.hook, name, hook)
                elif hook.has_spec():
                    self._verify_hook(hook, hookimpl)
                    hook._maybe_apply_history(hookimpl)
                hook._add_hookimpl(hookimpl)
                hookcallers.append(hook)
        return plugin_name

    def parse_hookimpl_opts(self, plugin, name):
        method = getattr(plugin, name)
        res = getattr(method, self.project_name + "_impl", None)
        if res is not None and not isinstance(res, dict):
            # false positive
            res = None
        elif res is None and self._implprefix and name.startswith(self._implprefix):
            res = {}
        return res

    def unregister(self, plugin=None, name=None):
        """ unregister a plugin object and all its contained hook implementations
        from internal data structures. """
        if name is None:
            assert plugin is not None, "one of name or plugin needs to be specified"
            name = self.get_name(plugin)

        if plugin is None:
            plugin = self.get_plugin(name)

        # if self._name2plugin[name] == None registration was blocked: ignore
        if self._name2plugin.get(name):
            del self._name2plugin[name]

        for hookcaller in self._plugin2hookcallers.pop(plugin, []):
            hookcaller._remove_plugin(plugin)

        return plugin

    def set_blocked(self, name):
        """ block registrations of the given name, unregister if already registered. """
        self.unregister(name=name)
        self._name2plugin[name] = None

    def is_blocked(self, name):
        """ return True if the name blogs registering plugins of that name. """
        return name in self._name2plugin and self._name2plugin[name] is None

    def add_hookspecs(self, module_or_class):
        """ add new hook specifications defined in the given module_or_class.
        Functions are recognized if they have been decorated accordingly. """
        names = []
        for name in dir(module_or_class):
            spec_opts = self.parse_hookspec_opts(module_or_class, name)
            if spec_opts is not None:
                hc = getattr(self.hook, name, None)
                if hc is None:
                    hc = _HookCaller(name, self._hookexec, module_or_class, spec_opts)
                    setattr(self.hook, name, hc)
                else:
                    # plugins registered this hook without knowing the spec
                    hc.set_specification(module_or_class, spec_opts)
                    for hookfunction in (hc._wrappers + hc._nonwrappers):
                        self._verify_hook(hc, hookfunction)
                names.append(name)

        if not names:
            raise ValueError("did not find any %r hooks in %r" %
                             (self.project_name, module_or_class))

    def parse_hookspec_opts(self, module_or_class, name):
        method = getattr(module_or_class, name)
        return getattr(method, self.project_name + "_spec", None)

    def get_plugins(self):
        """ return the set of registered plugins. """
        return set(self._plugin2hookcallers)

    def is_registered(self, plugin):
        """ Return True if the plugin is already registered. """
        return plugin in self._plugin2hookcallers

    def get_canonical_name(self, plugin):
        """ Return canonical name for a plugin object. Note that a plugin
        may be registered under a different name which was specified
        by the caller of register(plugin, name). To obtain the name
        of an registered plugin use ``get_name(plugin)`` instead."""
        return getattr(plugin, "__name__", None) or str(id(plugin))

    def get_plugin(self, name):
        """ Return a plugin or None for the given name. """
        return self._name2plugin.get(name)

    def get_name(self, plugin):
        """ Return name for registered plugin or None if not registered. """
        for name, val in self._name2plugin.items():
            if plugin == val:
                return name

    def _verify_hook(self, hook, hookimpl):
        if hook.is_historic() and hookimpl.hookwrapper:
            raise PluginValidationError(
                "Plugin %r\nhook %r\nhistoric incompatible to hookwrapper" %
                (hookimpl.plugin_name, hook.name))

        for arg in hookimpl.argnames:
            if arg not in hook.argnames:
                raise PluginValidationError(
                    "Plugin %r\nhook %r\nargument %r not available\n"
                    "plugin definition: %s\n"
                    "available hookargs: %s" %
                    (hookimpl.plugin_name, hook.name, arg,
                    _formatdef(hookimpl.function), ", ".join(hook.argnames)))

    def check_pending(self):
        """ Verify that all hooks which have not been verified against
        a hook specification are optional, otherwise raise PluginValidationError"""
        for name in self.hook.__dict__:
            if name[0] != "_":
                hook = getattr(self.hook, name)
                if not hook.has_spec():
                    for hookimpl in (hook._wrappers + hook._nonwrappers):
                        if not hookimpl.optionalhook:
                            raise PluginValidationError(
                                "unknown hook %r in plugin %r" %
                                (name, hookimpl.plugin))

    def load_setuptools_entrypoints(self, entrypoint_name):
        """ Load modules from querying the specified setuptools entrypoint name.
        Return the number of loaded plugins. """
        from pkg_resources import iter_entry_points, DistributionNotFound
        for ep in iter_entry_points(entrypoint_name):
            # is the plugin registered or blocked?
            if self.get_plugin(ep.name) or self.is_blocked(ep.name):
                continue
            try:
                plugin = ep.load()
            except DistributionNotFound:
                continue
            self.register(plugin, name=ep.name)
            self._plugin_distinfo.append((plugin, ep.dist))
        return len(self._plugin_distinfo)

    def list_plugin_distinfo(self):
        """ return list of distinfo/plugin tuples for all setuptools registered
        plugins. """
        return list(self._plugin_distinfo)

    def list_name_plugin(self):
        """ return list of name/plugin pairs. """
        return list(self._name2plugin.items())

    def get_hookcallers(self, plugin):
        """ get all hook callers for the specified plugin. """
        return self._plugin2hookcallers.get(plugin)

    def add_hookcall_monitoring(self, before, after):
        """ add before/after tracing functions for all hooks
        and return an undo function which, when called,
        will remove the added tracers.

        ``before(hook_name, hook_impls, kwargs)`` will be called ahead
        of all hook calls and receive a hookcaller instance, a list
        of HookImpl instances and the keyword arguments for the hook call.

        ``after(outcome, hook_name, hook_impls, kwargs)`` receives the
        same arguments as ``before`` but also a :py:class:`_CallOutcome`` object
        which represents the result of the overall hook call.
        """
        return _TracedHookExecution(self, before, after).undo

    def enable_tracing(self):
        """ enable tracing of hook calls and return an undo function. """
        hooktrace = self.hook._trace

        def before(hook_name, methods, kwargs):
            hooktrace.root.indent += 1
            hooktrace(hook_name, kwargs)

        def after(outcome, hook_name, methods, kwargs):
            if outcome.excinfo is None:
                hooktrace("finish", hook_name, "-->", outcome.result)
            hooktrace.root.indent -= 1

        return self.add_hookcall_monitoring(before, after)

    def subset_hook_caller(self, name, remove_plugins):
        """ Return a new _HookCaller instance for the named method
        which manages calls to all registered plugins except the
        ones from remove_plugins. """
        orig = getattr(self.hook, name)
        plugins_to_remove = [plug for plug in remove_plugins if hasattr(plug, name)]
        if plugins_to_remove:
            hc = _HookCaller(orig.name, orig._hookexec, orig._specmodule_or_class,
                             orig.spec_opts)
            for hookimpl in (orig._wrappers + orig._nonwrappers):
                plugin = hookimpl.plugin
                if plugin not in plugins_to_remove:
                    hc._add_hookimpl(hookimpl)
                    # we also keep track of this hook caller so it
                    # gets properly removed on plugin unregistration
                    self._plugin2hookcallers.setdefault(plugin, []).append(hc)
            return hc
        return orig


class _MultiCall:
    """ execute a call into multiple python functions/methods. """

    # XXX note that the __multicall__ argument is supported only
    # for pytest compatibility reasons.  It was never officially
    # supported there and is explicitly deprecated since 2.8
    # so we can remove it soon, allowing to avoid the below recursion
    # in execute() and simplify/speed up the execute loop.

    def __init__(self, hook_impls, kwargs, specopts={}):
        self.hook_impls = hook_impls
        self.kwargs = kwargs
        self.kwargs["__multicall__"] = self
        self.specopts = specopts

    def execute(self):
        all_kwargs = self.kwargs
        self.results = results = []
        firstresult = self.specopts.get("firstresult")

        while self.hook_impls:
            hook_impl = self.hook_impls.pop()
            args = [all_kwargs[argname] for argname in hook_impl.argnames]
            if hook_impl.hookwrapper:
                return _wrapped_call(hook_impl.function(*args), self.execute)
            res = hook_impl.function(*args)
            if res is not None:
                if firstresult:
                    return res
                results.append(res)

        if not firstresult:
            return results

    def __repr__(self):
        status = "%d meths" % (len(self.hook_impls),)
        if hasattr(self, "results"):
            status = ("%d results, " % len(self.results)) + status
        return "<_MultiCall %s, kwargs=%r>" % (status, self.kwargs)


def varnames(func, startindex=None):
    """ return argument name tuple for a function, method, class or callable.

    In case of a class, its "__init__" method is considered.
    For methods the "self" parameter is not included unless you are passing
    an unbound method with Python3 (which has no supports for unbound methods)
    """
    cache = getattr(func, "__dict__", {})
    try:
        return cache["_varnames"]
    except KeyError:
        pass
    if inspect.isclass(func):
        try:
            func = func.__init__
        except AttributeError:
            return ()
        startindex = 1
    else:
        if not inspect.isfunction(func) and not inspect.ismethod(func):
            func = getattr(func, '__call__', func)
        if startindex is None:
            startindex = int(inspect.ismethod(func))

    try:
        rawcode = func.__code__
    except AttributeError:
        return ()
    try:
        x = rawcode.co_varnames[startindex:rawcode.co_argcount]
    except AttributeError:
        x = ()
    else:
        defaults = func.__defaults__
        if defaults:
            x = x[:-len(defaults)]
    try:
        cache["_varnames"] = x
    except TypeError:
        pass
    return x


class _HookRelay:
    """ hook holder object for performing 1:N hook calls where N is the number
    of registered plugins.

    """

    def __init__(self, trace):
        self._trace = trace


class _HookCaller(object):
    def __init__(self, name, hook_execute, specmodule_or_class=None, spec_opts=None):
        self.name = name
        self._wrappers = []
        self._nonwrappers = []
        self._hookexec = hook_execute
        if specmodule_or_class is not None:
            assert spec_opts is not None
            self.set_specification(specmodule_or_class, spec_opts)

    def has_spec(self):
        return hasattr(self, "_specmodule_or_class")

    def set_specification(self, specmodule_or_class, spec_opts):
        assert not self.has_spec()
        self._specmodule_or_class = specmodule_or_class
        specfunc = getattr(specmodule_or_class, self.name)
        argnames = varnames(specfunc, startindex=inspect.isclass(specmodule_or_class))
        assert "self" not in argnames  # sanity check
        self.argnames = ["__multicall__"] + list(argnames)
        self.spec_opts = spec_opts
        if spec_opts.get("historic"):
            self._call_history = []

    def is_historic(self):
        return hasattr(self, "_call_history")

    def _remove_plugin(self, plugin):
        def remove(wrappers):
            for i, method in enumerate(wrappers):
                if method.plugin == plugin:
                    del wrappers[i]
                    return True
        if remove(self._wrappers) is None:
            if remove(self._nonwrappers) is None:
                raise ValueError("plugin %r not found" % (plugin,))

    def _add_hookimpl(self, hookimpl):
        if hookimpl.hookwrapper:
            methods = self._wrappers
        else:
            methods = self._nonwrappers

        if hookimpl.trylast:
            methods.insert(0, hookimpl)
        elif hookimpl.tryfirst:
            methods.append(hookimpl)
        else:
            # find last non-tryfirst method
            i = len(methods) - 1
            while i >= 0 and methods[i].tryfirst:
                i -= 1
            methods.insert(i + 1, hookimpl)

    def __repr__(self):
        return "<_HookCaller %r>" % (self.name,)

    def __call__(self, **kwargs):
        assert not self.is_historic()
        return self._hookexec(self, self._nonwrappers + self._wrappers, kwargs)

    def call_historic(self, proc=None, kwargs=None):
        self._call_history.append((kwargs or {}, proc))
        # historizing hooks don't return results
        self._hookexec(self, self._nonwrappers + self._wrappers, kwargs)

    def call_extra(self, methods, kwargs):
        """ Call the hook with some additional temporarily participating
        methods using the specified kwargs as call parameters. """
        old = list(self._nonwrappers), list(self._wrappers)
        for method in methods:
            opts = dict(hookwrapper=False, trylast=False, tryfirst=False)
            hookimpl = HookImpl(None, "<temp>", method, opts)
            self._add_hookimpl(hookimpl)
        try:
            return self(**kwargs)
        finally:
            self._nonwrappers, self._wrappers = old

    def _maybe_apply_history(self, method):
        if self.is_historic():
            for kwargs, proc in self._call_history:
                res = self._hookexec(self, [method], kwargs)
                if res and proc is not None:
                    proc(res[0])


class HookImpl:
    def __init__(self, plugin, plugin_name, function, hook_impl_opts):
        self.function = function
        self.argnames = varnames(self.function)
        self.plugin = plugin
        self.opts = hook_impl_opts
        self.plugin_name = plugin_name
        self.__dict__.update(hook_impl_opts)


class PluginValidationError(Exception):
    """ plugin failed validation. """


if hasattr(inspect, 'signature'):
    def _formatdef(func):
        return "%s%s" % (
            func.__name__,
            str(inspect.signature(func))
        )
else:
    def _formatdef(func):
        return "%s%s" % (
            func.__name__,
            inspect.formatargspec(*inspect.getargspec(func))
        )
