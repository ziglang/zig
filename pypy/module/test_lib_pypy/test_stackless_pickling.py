from py.test import skip
try:
    import stackless
except ImportError:
    try:
        from lib_pypy import stackless as stackless
    except ImportError as e:
        skip('cannot import stackless: %s' % (e,))



class Test_StacklessPickling:

    def test_pickle_main_coroutine(self):
        import stackless, pickle
        s = pickle.dumps(stackless.coroutine.getcurrent())
        print(s)
        c = pickle.loads(s)
        assert c is stackless.coroutine.getcurrent()

    def test_basic_tasklet_pickling(self):
        import stackless
        from stackless import run, schedule, tasklet
        import pickle

        output = []

        import new

        mod = new.module('mod')
        mod.output = output

        exec("""from stackless import schedule
        
def aCallable(name):
    output.append(('b', name))
    schedule()
    output.append(('a', name))
""", mod.__dict__)
        import sys
        sys.modules['mod'] = mod
        aCallable = mod.aCallable


        tasks = []
        for name in "ABCDE":
            tasks.append(tasklet(aCallable)(name))

        schedule()

        assert output == [('b', x) for x in "ABCDE"]
        del output[:]
        pickledTasks = pickle.dumps(tasks)

        schedule()
        assert output == [('a', x) for x in "ABCDE"]
        del output[:]
        
        unpickledTasks = pickle.loads(pickledTasks)
        for task in unpickledTasks:
            task.insert()

        schedule()
        assert output == [('a', x) for x in "ABCDE"]

