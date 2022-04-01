
import py

from pypy.tool.bench.pypyresult import ResultDB, BenchResult
import pickle

def setup_module(mod):
    mod.tmpdir = py.test.ensuretemp(__name__) 

def gettestpickle(cache=[]):
    if cache:
        return cache[0]
    pp = tmpdir.join("testpickle")
    f = pp.open("wb")
    pickle.dump({'./pypy-llvm-39474-O3-c_richards': 5}, f)
    pickle.dump({'./pypy-llvm-39474-O3-c_richards': 42.0}, f)
    f.close()
    cache.append(pp)
    return pp

def test_unpickle():
    pp = gettestpickle()
    db = ResultDB()
    db.parsepickle(pp)
    assert len(db.benchmarks) == 1
    l = db.getbenchmarks(name="richards")
    assert len(l) == 1
    bench = l[0]
    l = db.getbenchmarks(name="xyz")
    assert not l

def test_BenchResult_cpython():
    res = BenchResult("2.3.5_pystone", besttime=2.0, numruns=3)
    assert res.executable == "cpython"
    assert res.revision == "2.3.5"
    assert res.name == "pystone"
    assert res.numruns == 3
    assert res.besttime == 2.0

def test_BenchResult_pypy():
    res = BenchResult("pypy-llvm-39474-O3-c_richards",
                      besttime=2.0, numruns=3)
    assert res.executable == "pypy-llvm-39474-O3-c"
    assert res.revision == 39474
    assert res.name == "richards"
    assert res.numruns == 3
    assert res.besttime == 2.0
