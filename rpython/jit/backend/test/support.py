import py
import sys
from rpython.rlib.debug import debug_print
from rpython.translator.translator import TranslationContext, graphof
from rpython.jit.metainterp.optimizeopt import ALL_OPTS_NAMES
from rpython.rlib.rarithmetic import is_valid_int

class BaseCompiledMixin(object):

    CPUClass = None
    basic = False

    def _get_TranslationContext(self):
        return TranslationContext()

    def _compile_and_run(self, t, entry_point, entry_point_graph, args):
        raise NotImplementedError

    # XXX backendopt is ignored
    def meta_interp(self, function, args, repeat=1, inline=False, trace_limit=sys.maxint,
                    backendopt=None, listcomp=False, **kwds): # XXX ignored
        from rpython.jit.metainterp.warmspot import WarmRunnerDesc
        from rpython.annotator.listdef import s_list_of_strings
        from rpython.annotator import model as annmodel

        for arg in args:
            assert is_valid_int(arg)

        self.pre_translation_hook()
        t = self._get_TranslationContext()
        if listcomp:
            t.config.translation.list_comprehension_operations = True

        arglist = ", ".join(['int(argv[%d])' % (i + 1) for i in range(len(args))])
        if len(args) == 1:
            arglist += ','
        arglist = '(%s)' % arglist
        if repeat != 1:
            src = py.code.Source("""
            def entry_point(argv):
                args = %s
                res = function(*args)
                for k in range(%d - 1):
                    res = function(*args)
                print res
                return 0
            """ % (arglist, repeat))
        else:
            src = py.code.Source("""
            def entry_point(argv):
                args = %s
                res = function(*args)
                print res
                return 0
            """ % (arglist,))
        exec(src.compile(), locals())

        t.buildannotator().build_types(function, [int] * len(args),
                                       main_entry_point=True)
        t.buildrtyper().specialize()
        warmrunnerdesc = WarmRunnerDesc(t, translate_support_code=True,
                                        CPUClass=self.CPUClass,
                                        **kwds)
        for jd in warmrunnerdesc.jitdrivers_sd:
            jd.warmstate.set_param_threshold(3)          # for tests
            jd.warmstate.set_param_trace_eagerness(2)    # for tests
            jd.warmstate.set_param_trace_limit(trace_limit)
            jd.warmstate.set_param_inlining(inline)
            jd.warmstate.set_param_enable_opts(ALL_OPTS_NAMES)
        mixlevelann = warmrunnerdesc.annhelper
        entry_point_graph = mixlevelann.getgraph(entry_point, [s_list_of_strings],
                                                 annmodel.SomeInteger())
        warmrunnerdesc.finish()
        self.post_translation_hook()
        return self._compile_and_run(t, entry_point, entry_point_graph, args)

    def pre_translation_hook(self):
        pass

    def post_translation_hook(self):
        pass

    def check_loops(self, *args, **kwds):
        pass

    def check_loop_count(self, *args, **kwds):
        pass

    def check_tree_loop_count(self, *args, **kwds):
        pass

    def check_enter_count(self, *args, **kwds):
        pass

    def check_enter_count_at_most(self, *args, **kwds):
        pass

    def check_max_trace_length(self, *args, **kwds):
        pass

    def check_aborted_count(self, *args, **kwds):
        pass

    def check_aborted_count_at_least(self, *args, **kwds):
        pass

    def interp_operations(self, *args, **kwds):
        py.test.skip("interp_operations test skipped")


class CCompiledMixin(BaseCompiledMixin):
    slow = False

    def setup_class(cls):
        if cls.slow:
            from rpython.jit.conftest import option
            if not option.run_slow_tests:
                py.test.skip("use --slow to execute this long-running test")

    def _get_TranslationContext(self):
        t = TranslationContext()
        t.config.translation.gc = 'boehm'
        t.config.translation.list_comprehension_operations = True
        return t

    def _compile_and_run(self, t, entry_point, entry_point_graph, args):
        from rpython.translator.c.genc import CStandaloneBuilder as CBuilder
        # XXX patch exceptions
        cbuilder = CBuilder(t, entry_point, config=t.config)
        cbuilder.generate_source()
        self._check_cbuilder(cbuilder)
        exe_name = cbuilder.compile()
        debug_print('---------- Test starting ----------')
        stdout = cbuilder.cmdexec(" ".join([str(arg) for arg in args]))
        res = int(stdout)
        debug_print('---------- Test done (%d) ----------' % (res,))
        return res

    def _check_cbuilder(self, cbuilder):
        pass
