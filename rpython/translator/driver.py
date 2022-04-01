import sys, os
import os.path
import shutil

from rpython.translator.translator import TranslationContext
from rpython.translator.tool.taskengine import SimpleTaskEngine
from rpython.translator.goal import query
from rpython.translator.goal.timing import Timer
from rpython.annotator.listdef import s_list_of_strings
from rpython.annotator import policy as annpolicy
from rpython.tool.udir import udir
from rpython.rlib.debug import debug_start, debug_print, debug_stop
from rpython.rlib.entrypoint import secondary_entrypoints,\
     annotated_jit_entrypoints

import py
from rpython.tool.ansi_print import AnsiLogger

log = AnsiLogger("translation")


def taskdef(deps, title, new_state=None, expected_states=[],
            idemp=False, earlycheck=None):
    def decorator(taskfunc):
        taskfunc.task_deps = deps
        taskfunc.task_title = title
        taskfunc.task_newstate = None
        taskfunc.task_expected_states = expected_states
        taskfunc.task_idempotent = idemp
        taskfunc.task_earlycheck = earlycheck
        return taskfunc
    return decorator

# TODO:
# sanity-checks using states

# set of translation steps to profile
PROFILE = set([])

class Instrument(Exception):
    pass


class ProfInstrument(object):
    name = "profinstrument"
    def __init__(self, datafile, compiler):
        self.datafile = datafile
        self.compiler = compiler

    def first(self):
        return self.compiler._build()

    def probe(self, exe, args):
        env = os.environ.copy()
        env['PYPY_INSTRUMENT_COUNTERS'] = str(self.datafile)
        self.compiler.platform.execute(exe, args, env=env)

    def after(self):
        # xxx
        os._exit(0)


class TranslationDriver(SimpleTaskEngine):
    _backend_extra_options = {}

    def __init__(self, setopts=None, default_goal=None,
                 disable=[],
                 exe_name=None, extmod_name=None,
                 config=None, overrides=None):
        from rpython.config import translationoption
        self.timer = Timer()
        SimpleTaskEngine.__init__(self)

        self.log = log

        if config is None:
            config = translationoption.get_combined_translation_config(translating=True)
        # XXX patch global variable with translation config
        translationoption._GLOBAL_TRANSLATIONCONFIG = config
        self.config = config
        if overrides is not None:
            self.config.override(overrides)

        if setopts is not None:
            self.config.set(**setopts)

        self.exe_name = exe_name
        self.extmod_name = extmod_name

        self.done = {}

        self.disable(disable)

        if default_goal:
            default_goal, = self.backend_select_goals([default_goal])
            if default_goal in self._maybe_skip():
                default_goal = None

        self.default_goal = default_goal
        self.extra_goals = []
        self.exposed = []

        # expose tasks
        def expose_task(task, backend_goal=None):
            if backend_goal is None:
                backend_goal = task
            def proc():
                return self.proceed(backend_goal)
            self.exposed.append(task)
            setattr(self, task, proc)

        backend, ts = self.get_backend_and_type_system()
        for task in self.tasks:
            explicit_task = task
            if task == 'annotate':
                expose_task(task)
            else:
                task, postfix = task.split('_')
                if task in ('rtype', 'backendopt', 'llinterpret',
                            'pyjitpl'):
                    if ts:
                        if ts == postfix:
                            expose_task(task, explicit_task)
                    else:
                        expose_task(explicit_task)
                elif task in ('source', 'compile', 'run'):
                    if backend:
                        if backend == postfix:
                            expose_task(task, explicit_task)
                    elif ts:
                        if ts == 'lltype':
                            expose_task(explicit_task)
                    else:
                        expose_task(explicit_task)

    def set_extra_goals(self, goals):
        self.extra_goals = goals

    def set_backend_extra_options(self, extra_options):
        self._backend_extra_options = extra_options

    def get_info(self): # XXX more?
        d = {'backend': self.config.translation.backend}
        return d

    def get_backend_and_type_system(self):
        type_system = self.config.translation.type_system
        backend = self.config.translation.backend
        return backend, type_system

    def backend_select_goals(self, goals):
        backend, ts = self.get_backend_and_type_system()
        postfixes = [''] + ['_'+p for p in (backend, ts) if p]
        l = []
        for goal in goals:
            for postfix in postfixes:
                cand = "%s%s" % (goal, postfix)
                if cand in self.tasks:
                    new_goal = cand
                    break
            else:
                raise Exception("cannot infer complete goal from: %r" % goal)
            l.append(new_goal)
        return l

    def disable(self, to_disable):
        self._disabled = to_disable

    def _maybe_skip(self):
        maybe_skip = []
        if self._disabled:
            for goal in self.backend_select_goals(self._disabled):
                maybe_skip.extend(self._depending_on_closure(goal))
        return dict.fromkeys(maybe_skip).keys()

    def setup(self, entry_point, inputtypes, policy=None, extra={}, empty_translator=None):
        standalone = inputtypes is None
        self.standalone = standalone

        if standalone:
            # the 'argv' parameter
            inputtypes = [s_list_of_strings]
        self.inputtypes = inputtypes

        if policy is None:
            policy = annpolicy.AnnotatorPolicy()
        self.policy = policy

        self.extra = extra

        if empty_translator:
            translator = empty_translator
        else:
            translator = TranslationContext(config=self.config)

        self.entry_point = entry_point
        self.translator = translator
        self.libdef = None
        self.secondary_entrypoints = []

        if self.config.translation.secondaryentrypoints:
            for key in self.config.translation.secondaryentrypoints.split(","):
                try:
                    points = secondary_entrypoints[key]
                except KeyError:
                    raise KeyError("Entrypoint %r not found (not in %r)" %
                                   (key, secondary_entrypoints.keys()))
                self.secondary_entrypoints.extend(points)

        self.translator.driver_instrument_result = self.instrument_result

    def setup_library(self, libdef, policy=None, extra={}, empty_translator=None):
        """ Used by carbon python only. """
        self.setup(None, None, policy, extra, empty_translator)
        self.libdef = libdef
        self.secondary_entrypoints = libdef.functions

    def instrument_result(self, args):
        backend, ts = self.get_backend_and_type_system()
        if backend != 'c' or sys.platform == 'win32':
            raise Exception("instrumentation requires the c backend"
                            " and unix for now")

        datafile = udir.join('_instrument_counters')
        makeProfInstrument = lambda compiler: ProfInstrument(datafile, compiler)

        pid = os.fork()
        if pid == 0:
            # child compiling and running with instrumentation
            self.config.translation.instrument = True
            self.config.translation.instrumentctl = (makeProfInstrument,
                                                     args)
            raise Instrument
        else:
            pid, status = os.waitpid(pid, 0)
            if os.WIFEXITED(status):
                status = os.WEXITSTATUS(status)
                if status != 0:
                    raise Exception("instrumentation child failed: %d" % status)
            else:
                raise Exception("instrumentation child aborted")
            import array, struct
            n = datafile.size()//struct.calcsize('L')
            datafile = datafile.open('rb')
            counters = array.array('L')
            counters.fromfile(datafile, n)
            datafile.close()
            return counters

    def info(self, msg):
        log.info(msg)

    def _profile(self, goal, func):
        from cProfile import Profile
        from rpython.tool.lsprofcalltree import KCacheGrind
        d = {'func':func}
        prof = Profile()
        prof.runctx("res = func()", globals(), d)
        KCacheGrind(prof).output(open(goal + ".out", "w"))
        return d['res']

    def _do(self, goal, func, *args, **kwds):
        title = func.task_title
        if goal in self.done:
            self.log.info("already done: %s" % title)
            return
        else:
            self.log.info("%s..." % title)
        debug_start('translation-task')
        debug_print('starting', goal)
        self.timer.start_event(goal)
        try:
            instrument = False
            try:
                if goal in PROFILE:
                    res = self._profile(goal, func)
                else:
                    res = func()
            except Instrument:
                instrument = True
            if not func.task_idempotent:
                self.done[goal] = True
            if instrument:
                self.proceed('compile')
                assert False, 'we should not get here'
        finally:
            try:
                debug_stop('translation-task')
                self.timer.end_event(goal)
            except (KeyboardInterrupt, SystemExit):
                raise
            except:
                pass
        #import gc; gc.dump_rpy_heap('rpyheap-after-%s.dump' % goal)
        return res

    @taskdef([], "Annotating&simplifying")
    def task_annotate(self):
        """ Annotate
        """
        # includes annotation and annotatation simplifications
        translator = self.translator
        policy = self.policy
        self.log.info('with policy: %s.%s' % (policy.__class__.__module__, policy.__class__.__name__))

        annotator = translator.buildannotator(policy=policy)

        if self.secondary_entrypoints is not None:
            for func, inputtypes in self.secondary_entrypoints:
                if inputtypes == Ellipsis:
                    continue
                annotator.build_types(func, inputtypes, False)

        if self.entry_point:
            s = annotator.build_types(self.entry_point, self.inputtypes)
            translator.entry_point_graph = annotator.bookkeeper.getdesc(self.entry_point).getuniquegraph()
        else:
            s = None

        self.sanity_check_annotation()
        if self.entry_point and self.standalone and s.knowntype != int:
            raise Exception("stand-alone program entry point must return an "
                            "int (and not, e.g., None or always raise an "
                            "exception).")
        annotator.complete()
        annotator.simplify()
        return s


    def sanity_check_annotation(self):
        translator = self.translator
        irreg = query.qoutput(query.check_exceptblocks_qgen(translator))
        if irreg:
            self.log.info("Some exceptblocks seem insane")

        lost = query.qoutput(query.check_methods_qgen(translator))
        assert not lost, "lost methods, something gone wrong with the annotation of method defs"

    RTYPE = 'rtype_lltype'
    @taskdef(['annotate'], "RTyping")
    def task_rtype_lltype(self):
        """ RTyping - lltype version
        """
        rtyper = self.translator.buildrtyper()
        rtyper.specialize(dont_simplify_again=True)

    @taskdef([RTYPE], "JIT compiler generation")
    def task_pyjitpl_lltype(self):
        """ Generate bytecodes for JIT and flow the JIT helper functions
        lltype version
        """
        from rpython.jit.codewriter.policy import JitPolicy
        get_policy = self.extra.get('jitpolicy', None)
        if get_policy is None:
            self.jitpolicy = JitPolicy()
        else:
            self.jitpolicy = get_policy(self)
        #
        from rpython.jit.metainterp.warmspot import apply_jit
        apply_jit(self.translator, policy=self.jitpolicy,
                  backend_name=self.config.translation.jit_backend, inline=True)
        #
        self.log.info("the JIT compiler was generated")

    @taskdef([RTYPE], "test of the JIT on the llgraph backend")
    def task_jittest_lltype(self):
        """ Run with the JIT on top of the llgraph backend
        """
        # parent process loop: spawn a child, wait for the child to finish,
        # print a message, and restart
        from rpython.translator.goal import unixcheckpoint
        unixcheckpoint.restartable_point(auto='run')
        # load the module rpython/jit/tl/jittest.py, which you can hack at
        # and restart without needing to restart the whole translation process
        from rpython.jit.tl import jittest
        jittest.jittest(self)

    BACKENDOPT = 'backendopt_lltype'
    @taskdef([RTYPE, '??pyjitpl_lltype', '??jittest_lltype'], "lltype back-end optimisations")
    def task_backendopt_lltype(self):
        """ Run all backend optimizations - lltype version
        """
        from rpython.translator.backendopt.all import backend_optimizations
        backend_optimizations(self.translator, replace_we_are_jitted=True)


    STACKCHECKINSERTION = 'stackcheckinsertion_lltype'
    @taskdef(['?'+BACKENDOPT, RTYPE, 'annotate'], "inserting stack checks")
    def task_stackcheckinsertion_lltype(self):
        from rpython.translator.transform import insert_ll_stackcheck
        count = insert_ll_stackcheck(self.translator)
        self.log.info("inserted %d stack checks." % (count,))


    def possibly_check_for_boehm(self):
        if self.config.translation.gc == "boehm":
            from rpython.rtyper.tool.rffi_platform import configure_boehm
            from rpython.translator.platform import CompilationError
            try:
                configure_boehm(self.translator.platform)
            except CompilationError as e:
                i = 'Boehm GC not installed.  Try e.g. "translate.py --gc=minimark"'
                raise Exception(str(e) + '\n' + i)

    @taskdef([STACKCHECKINSERTION, '?'+BACKENDOPT, RTYPE, '?annotate'],
        "Creating database for generating c source",
        earlycheck = possibly_check_for_boehm)
    def task_database_c(self):
        """ Create a database for further backend generation
        """
        translator = self.translator
        if translator.annotator is not None:
            translator.frozen = True

        standalone = self.standalone
        get_gchooks = self.extra.get('get_gchooks', lambda: None)
        gchooks = get_gchooks()

        if standalone:
            from rpython.translator.c.genc import CStandaloneBuilder
            cbuilder = CStandaloneBuilder(self.translator, self.entry_point,
                                          config=self.config, gchooks=gchooks,
                      secondary_entrypoints=
                      self.secondary_entrypoints + annotated_jit_entrypoints)
        else:
            from rpython.translator.c.dlltool import CLibraryBuilder
            functions = [(self.entry_point, None)] + self.secondary_entrypoints + annotated_jit_entrypoints
            cbuilder = CLibraryBuilder(self.translator, self.entry_point,
                                       functions=functions,
                                       name='libtesting',
                                       config=self.config,
                                       gchooks=gchooks)
        if not standalone:     # xxx more messy
            cbuilder.modulename = self.extmod_name
        database = cbuilder.build_database()
        self.log.info("database for generating C source was created")
        self.cbuilder = cbuilder
        self.database = database

    @taskdef(['database_c'], "Generating c source")
    def task_source_c(self):
        """ Create C source files from the generated database
        """
        cbuilder = self.cbuilder
        database = self.database
        if self._backend_extra_options.get('c_debug_defines', False):
            defines = cbuilder.DEBUG_DEFINES
        else:
            defines = {}
        if self.exe_name is not None:
            exe_name = self.exe_name % self.get_info()
        else:
            exe_name = None
        c_source_filename = cbuilder.generate_source(database, defines,
                                                     exe_name=exe_name)
        self.log.info("written: %s" % (c_source_filename,))
        if self.config.translation.dump_static_data_info:
            from rpython.translator.tool.staticsizereport import dump_static_data_info
            targetdir = cbuilder.targetdir
            fname = dump_static_data_info(self.log, database, targetdir)
            dstname = self.compute_exe_name() + '.staticdata.info'
            shutil_copy(str(fname), str(dstname))
            self.log.info('Static data info written to %s' % dstname)

    def compute_exe_name(self, suffix=''):
        newexename = self.exe_name % self.get_info()
        if '/' not in newexename and '\\' not in newexename:
            newexename = './' + newexename
        if suffix:
            # Replace the last `.sfx` with the suffix
            newname = py.path.local(newexename.rsplit('.', 1)[0])
            newname = newname.new(basename=newname.basename + suffix)
            return newname
        return py.path.local(newexename)

    def create_exe(self):
        """ Copy the compiled executable into current directory, which is
            pypy/goal on nightly builds
        """
        if self.exe_name is not None:
            exename = self.c_entryp
            newexename = py.path.local(exename.basename)
            shutil_copy(str(exename), str(newexename))
            self.log.info("copied: %s to %s" % (exename, newexename,))
            if self.cbuilder.shared_library_name is not None:
                soname = self.cbuilder.shared_library_name
                newsoname = newexename.new(basename=soname.basename)
                shutil_copy(str(soname), str(newsoname))
                self.log.info("copied: %s to %s" % (soname, newsoname,))
                if hasattr(self.cbuilder, 'executable_name_w'):
                    # Copy pypyw.exe
                    exename_w = self.cbuilder.executable_name_w
                    newexename_w = py.path.local(exename_w.basename)
                    self.log.info("copied: %s to %s" % (exename_w, newexename_w,))
                    shutil_copy(str(exename_w), str(newexename_w))
                    # for pypy, the import library is renamed and moved to
                    # libs/python32.lib, according to the pragma in pyconfig.h
                    libname = self.config.translation.libname
                    oldlibname = soname.new(ext='lib')
                    if not libname:
                        libname = oldlibname.basename
                        libname = str(newsoname.dirpath().join(libname))
                    shutil.copyfile(str(oldlibname), libname)
                    self.log.info("copied: %s to %s" % (oldlibname, libname,))
                    # the pdb file goes in the same place as pypy(w).exe
                    ext_to_copy = ['pdb',]
                    for ext in ext_to_copy:
                        name = soname.new(ext=ext)
                        newname = newexename.new(basename=soname.basename)
                        shutil.copyfile(str(name), str(newname.new(ext=ext)))
                        self.log.info("copied: %s" % (newname,))
                    # HACK: copy libcffi-*.dll which is required for venvs
                    # At some point, we should stop doing this, and instead
                    # use the artifact from packaging the build instead
                    libffi = py.path.local.sysfind('libffi-8.dll')
                    if sys.platform == 'win32' and not libffi:
                        raise RuntimeError('could not find libffi')
                    elif libffi:
                        # in tests, we can mock using windows without libffi
                        shutil.copyfile(str(libffi), os.getcwd() + r'\libffi-8.dll')
            self.c_entryp = newexename
        self.log.info("created: %s" % (self.c_entryp,))

    @taskdef(['source_c'], "Compiling c source")
    def task_compile_c(self):
        """ Compile the generated C code using either makefile or
        translator/platform
        """
        cbuilder = self.cbuilder
        kwds = {}
        if self.standalone and self.exe_name is not None:
            kwds['exe_name'] = self.compute_exe_name().basename
        cbuilder.compile(**kwds)

        if self.standalone:
            self.c_entryp = cbuilder.executable_name
            self.create_exe()
        else:
            self.c_entryp = cbuilder.get_entry_point()

    @taskdef([STACKCHECKINSERTION, '?'+BACKENDOPT, RTYPE], "LLInterpreting")
    def task_llinterpret_lltype(self):
        from rpython.rtyper.llinterp import LLInterpreter

        translator = self.translator
        interp = LLInterpreter(translator.rtyper)
        bk = translator.annotator.bookkeeper
        graph = bk.getdesc(self.entry_point).getuniquegraph()
        v = interp.eval_graph(graph,
                              self.extra.get('get_llinterp_args',
                                             lambda: [])())

        log.llinterpret("result -> %s" % v)

    def proceed(self, goals):
        if not goals:
            if self.default_goal:
                goals = [self.default_goal]
            else:
                self.log.info("nothing to do")
                return
        elif isinstance(goals, str):
            goals = [goals]
        goals.extend(self.extra_goals)
        goals = self.backend_select_goals(goals)
        result = self._execute(goals, task_skip = self._maybe_skip())
        self.log.info('usession directory: %s' % (udir,))
        return result

    @classmethod
    def from_targetspec(cls, targetspec_dic, config=None, args=None,
                        empty_translator=None,
                        disable=[],
                        default_goal=None):
        if args is None:
            args = []

        driver = cls(config=config, default_goal=default_goal,
                     disable=disable)
        target = targetspec_dic['target']
        spec = target(driver, args)

        try:
            entry_point, inputtypes, policy = spec
        except TypeError:
            # not a tuple at all
            entry_point = spec
            inputtypes = policy = None
        except ValueError:
            policy = None
            entry_point, inputtypes = spec


        driver.setup(entry_point, inputtypes,
                     policy=policy,
                     extra=targetspec_dic,
                     empty_translator=empty_translator)
        return driver

    def prereq_checkpt_rtype(self):
        assert 'rpython.rtyper.rmodel' not in sys.modules, (
            "cannot fork because the rtyper has already been imported")
    prereq_checkpt_rtype_lltype = prereq_checkpt_rtype

    # checkpointing support
    def _event(self, kind, goal, func):
        if kind == 'planned' and func.task_earlycheck:
            func.task_earlycheck(self)
        if kind == 'pre':
            fork_before = self.config.translation.fork_before
            if fork_before:
                fork_before, = self.backend_select_goals([fork_before])
                if not fork_before in self.done and fork_before == goal:
                    prereq = getattr(self, 'prereq_checkpt_%s' % goal, None)
                    if prereq:
                        prereq()
                    from rpython.translator.goal import unixcheckpoint
                    unixcheckpoint.restartable_point(auto='run')

if os.name == 'posix':
    def shutil_copy(src, dst):
        # this version handles the case where 'dst' is an executable
        # currently being executed
        shutil.copy(src, dst + '~')
        os.rename(dst + '~', dst)
else:
    shutil_copy = shutil.copy
