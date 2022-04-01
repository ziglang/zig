"""
This file is imported by rpython.translator.driver when running the
target --pyjittest.  Feel free to hack it as needed; it is imported
only after the '---> Checkpoint' fork.
"""

import os
from rpython import conftest
from rpython.rtyper.llinterp import LLInterpreter
from rpython.rtyper.annlowlevel import llstr
from rpython.jit.metainterp import warmspot
from rpython.tool import runsubprocess

os.environ['PYPY_DONT_RUN_SUBPROCESS'] = '1'
reload(runsubprocess)


#ARGS = ["--jit", "threshold=100000,trace_eagerness=100000",
#        "-S", "/home/arigo/pypysrc/32compiled/z.py"]
ARGS = ["targettest_executable_name",
        "-r", "13", "/home/arigo/git/pyrlang/test_beam/fact.beam",
        "fact", "20000"]


def jittest(driver):
    graph = driver.translator._graphof(driver.entry_point)
    interp = LLInterpreter(driver.translator.rtyper)

    get_policy = driver.extra.get('jitpolicy', None)
    if get_policy is None:
        from rpython.jit.codewriter.policy import JitPolicy
        jitpolicy = JitPolicy()
    else:
        jitpolicy = get_policy(driver)

    from rpython.jit.backend.llgraph.runner import LLGraphCPU
    apply_jit(jitpolicy, interp, graph, LLGraphCPU)


def apply_jit(policy, interp, graph, CPUClass):
    print 'warmspot.jittify_and_run() started...'
    if conftest.option is None:
        class MyOpt:
            pass
        conftest.option = MyOpt()
    conftest.option.view = False
    conftest.option.viewloops = True   # XXX doesn't seem to work
    LIST = graph.getargs()[0].concretetype
    lst = LIST.TO.ll_newlist(len(ARGS))
    for i, arg in enumerate(ARGS):
        lst.ll_setitem_fast(i, llstr(arg))
    warmspot.jittify_and_run(interp, graph, [lst], policy=policy,
                             listops=True, CPUClass=CPUClass,
                             backendopt=True, inline=True)
