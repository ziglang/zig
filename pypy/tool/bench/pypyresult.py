import py

class ResultDB(object):
    def __init__(self):
        self.benchmarks = []

    def parsepickle(self, path):
        f = path.open("rb")
        id2numrun = py.std.pickle.load(f)
        id2bestspeed = py.std.pickle.load(f)
        f.close()
        for id in id2numrun:
            besttime = id2bestspeed[id]
            numruns = id2numrun[id]
            print id
            bench = BenchResult(id, besttime, numruns)
            self.benchmarks.append(bench)

    def getbenchmarks(self, name=None):
        l = []
        for bench in self.benchmarks: 
            if name is not None and name != bench.name:
                continue
            l.append(bench)
        return l 

class BenchResult(object):
    def __init__(self, id, besttime, numruns):
        self._id = id 
        if id.startswith("./"):
            id = id[2:]
        if id.startswith("pypy"):
            parts = id.rsplit("_", 1)
            self.executable = parts[0]
            self.name = parts[1]
            parts = self.executable.split("-")
            self.backend = parts[1]
            try:
                self.revision = int(parts[2])
            except ValueError:
                self.revision = None
        else: # presumably cpython
            version, name = id.split("_", 1)
            self.name = name
            self.backend = None
            self.revision = version
            self.executable = "cpython"
        self.besttime = besttime
        self.numruns = numruns
    def __repr__(self):
        return "<BenchResult %r>" %(self._id, )
            

if __name__ == "__main__":
    x = py.path.local(__file__).dirpath("bench-unix.benchmark_result")
    db = ResultDB()
    db.parsepickle(x)
    
