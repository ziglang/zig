from pypy.objspace.fake.checkmodule import checkmodule

def test_checkmodule():
    # we need to ignore GcCollectStepStats, else checkmodule fails. I think
    # this happens because W_GcCollectStepStats.__init__ is only called from
    # GcCollectStepHookAction.perform() and the fake objspace doesn't know
    # about those: so, perform() is never annotated and the annotator thinks
    # W_GcCollectStepStats has no attributes
    checkmodule('gc', ignore=['GcCollectStepStats'])
