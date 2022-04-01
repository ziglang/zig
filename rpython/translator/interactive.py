from rpython.translator.translator import TranslationContext
from rpython.translator import driver
from rpython.rlib.entrypoint import export_symbol


DEFAULTS = {
  'translation.backend': None,
  'translation.type_system': None,
  'translation.verbose': True,
}

class Translation(object):

    def __init__(self, entry_point, argtypes=None, **kwds):
        self.driver = driver.TranslationDriver(overrides=DEFAULTS)
        self.config = self.driver.config

        self.entry_point = export_symbol(entry_point)
        self.context = TranslationContext(config=self.config)

        policy = kwds.pop('policy', None)
        self.update_options(kwds)
        self.ensure_setup(argtypes, policy)
        # for t.view() to work just after construction
        graph = self.context.buildflowgraph(entry_point)
        self.context._prebuilt_graphs[entry_point] = graph

    def view(self):
        self.context.view()

    def viewcg(self):
        self.context.viewcg()

    def ensure_setup(self, argtypes=None, policy=None):
        self.driver.setup(self.entry_point, argtypes, policy,
                          empty_translator=self.context)
        self.ann_argtypes = argtypes
        self.ann_policy = policy

    def update_options(self, kwds):
        gc = kwds.pop('gc', None)
        if gc:
            self.config.translation.gc = gc
        self.config.translation.set(**kwds)

    def ensure_opt(self, name, value=None, fallback=None):
        if value is not None:
            self.update_options({name: value})
            return value
        val = getattr(self.config.translation, name, None)
        if fallback is not None and val is None:
            self.update_options({name: fallback})
            return fallback
        if val is not None:
            return val
        raise Exception(
                    "the %r option should have been specified at this point" % name)

    def ensure_type_system(self, type_system=None):
        if self.config.translation.backend is not None:
            return self.ensure_opt('type_system')
        return self.ensure_opt('type_system', type_system, 'lltype')

    def ensure_backend(self, backend=None):
        backend = self.ensure_opt('backend', backend)
        self.ensure_type_system()
        return backend

    # disable some goals (steps)
    def disable(self, to_disable):
        self.driver.disable(to_disable)

    def set_backend_extra_options(self, **extra_options):
        for name in extra_options:
            backend, option = name.split('_', 1)
            self.ensure_backend(backend)
        self.driver.set_backend_extra_options(extra_options)

    # backend independent

    def annotate(self, **kwds):
        self.update_options(kwds)
        return self.driver.annotate()

    # type system dependent

    def rtype(self, **kwds):
        self.update_options(kwds)
        ts = self.ensure_type_system()
        return getattr(self.driver, 'rtype_' + ts)()

    def backendopt(self, **kwds):
        self.update_options(kwds)
        ts = self.ensure_type_system('lltype')
        return getattr(self.driver, 'backendopt_' + ts)()

    # backend depedent

    def source(self, **kwds):
        self.update_options(kwds)
        backend = self.ensure_backend()
        getattr(self.driver, 'source_' + backend)()

    def source_c(self, **kwds):
        self.update_options(kwds)
        self.ensure_backend('c')
        self.driver.source_c()

    def source_cl(self, **kwds):
        self.update_options(kwds)
        self.ensure_backend('cl')
        self.driver.source_cl()

    def compile(self, **kwds):
        self.update_options(kwds)
        backend = self.ensure_backend()
        getattr(self.driver, 'compile_' + backend)()
        return self.driver.c_entryp

    def compile_c(self, **kwds):
        self.update_options(kwds)
        self.ensure_backend('c')
        self.driver.compile_c()
        return self.driver.c_entryp
