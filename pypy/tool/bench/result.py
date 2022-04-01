
import py

class PerfResult:
    """Holds information about a benchmark run of a particular test run."""
    
    def __init__(self, date=0.0, test_id="", revision=0.0, 
                 revision_id="NONE", timestamp=0.0,
                 revision_date=0.0, elapsed_time=-1, 
                 committer="", message="", nick=""): 
        self.__dict__.update(locals())
        del self.self

        
class PerfResultCollection(object):
    """Holds information about several PerfResult objects. The
    objects should have the same test_id and revision_id"""
    
    def __init__(self, results=None):
        if results is None:
            self.results = []
        else:
            self.results = results[:]
        #self.check()

    def __repr__(self):
        self.check()
        if not self.results:
            return "<PerfResultCollection EMPTY>"
        sample = self.results[0]
        return "<PerfResultCollection test_id=%s, revno=%s>" %(
               sample.test_id, sample.revision)
    
    @property   
    def min_elapsed(self):
        return self.getfastest().elapsed_time 

    def getfastest(self):
        x = None
        for res in self.results:
            if x is None or res.elapsed_time < x.elapsed_time: 
                x = res
        return x

    @property
    def test_id(self):
        # check for empty results?
        return self.results[0].test_id

    @property
    def revision_id(self):
        # check for empty results?
        return self.results[0].revision_id

    @property
    def revision(self):
        # check for empty results?
        return self.results[0].revision
           
    def check(self):
        for s1, s2 in zip(self.results, self.results[1:]):
            assert s1.revision_id == s2.revision_id 
            assert s1.test_id == s2.test_id
            assert s1.revision == s2.revision
            assert s1.date != s2.date
            
    def append(self, sample):
        self.results.append(sample)
        self.check()

    def extend(self, results):
        self.results.extend(results)
        self.check() 
        
    def __len__(self):
        return len(self.results)


class PerfResultDelta:
    """represents the difference of two PerfResultCollections"""

    def __init__(self, _from, _to=None): 
        if _from is None:
            _from = _to
        if _to is None:
            _to = _from
        if isinstance(_from, list):
            _from = PerfResultCollection(_from)
        if isinstance(_to, list):
            _to = PerfResultCollection(_to)
        assert isinstance(_from, PerfResultCollection)
        assert isinstance(_to, PerfResultCollection)
        assert _from.test_id == _to.test_id, (_from.test_id, _to.test_id)
        self._from = _from
        self._to = _to
        self.test_id = self._to.test_id
        self.delta = self._to.min_elapsed - self._from.min_elapsed 

        # percentage
        m1 = self._from.min_elapsed 
        m2 = self._to.min_elapsed 
        if m1 == 0: 
            self.percent = 0.0
        else:
            self.percent = float(m2-m1) / float(m1)

class PerfTable:
    """parses performance history data files and yields PerfResult objects
    through the get_results method.

    if an branch is given, it is used to get more information for each
    revision we have data from.
    """
    branch = None
    
    def __init__(self, iterlines = []):
        """:param iterline: lines of performance history data,
        e.g., history_file.realdlines()
        """
        self._revision_cache = {}
        self.results = list(self.parse(iterlines))
        
    def parse(self, iterlines):
        """parse lines like
        --date 1152625530.0 hacker@canonical.com-20..6dc
          1906ms bzrlib....one_add_kernel_like_tree
        """
        date = None
        revision_id = None
        for line in iterlines:
            line = line.strip()
            if not line:
                continue
            if line.startswith('--date'):
                _, date, revision_id = line.split(None, 2)
                date = float(date)
                continue
            perfresult = PerfResult(date=date, revision_id=revision_id)
            elapsed_time, test_id = line.split(None, 1)
            perfresult.elapsed_time = int(elapsed_time[:-2])
            perfresult.test_id = test_id.strip()
            yield self.annotate(perfresult)
        
    def add_lines(self, lines):
        """add lines of performance history data """
        
        self.results += list(self.parse(lines))

    def get_time_for_revision_id(self, revision_id):
        """return the data of the revision or 0"""
        if revision_id in self._revision_cache:
            return self._revision_cache[revision_id][1].timestamp
        return 0
        
    def get_time(self, revision_id):
        """return revision date or the date of recording the
        performance history data"""
        
        t = self.get_time_for_revision_id(revision_id)
        if t: 
            return t
        result = list(self.get_results(revision_ids=[revision_id],
                                       sorted_by_rev_date=False))[0]
        return result.date
   
    count = py.std.itertools.count() 
    def annotate(self, result):
        """Try to put extra information for each revision on the
        PerfResult objects. These information are retrieved from a
        branch object.
        """
        #if self.branch is None:
        #    return result
        class Branch:
            revision_id = result.revision_id  
            nick = "fake"
        
        self.branch = Branch()
        result.revision = self.count.next()
        result.revision_date = "01/01/2007"
        result.message = "fake log message"
        result.timestamp = 1231231.0
        return result
        

        revision_id = result.revision_id
        if revision_id in self._revision_cache:
            revision, rev, nick = self._revision_cache[revision_id]
        else:
            revision =  self.branch.revision_id_to_revno(revision_id)
            rev = self.branch.repository.get_revision(revision_id)
            nick = self.branch._get_nick()
            self._revision_cache[revision_id] = (revision, rev, nick)
            
        result.revision = revision
        result.committer = rev.committer
        result.message = rev.message
        result.timstamp = rev.timestamp
        # XXX no format_date, but probably this whole function
        # goes away soon
        result.revision_date = format_date(rev.timestamp, rev.timezone or 0)
        result.nick = nick
        return result
    
    def get_results(self, test_ids=None, revision_ids=None,
                    sorted_by_rev_date=True):
        # XXX we might want to build indexes for speed
        for result in self.results:
            if test_ids and result.test_id not in test_ids:
                continue
            if revision_ids and result.revision_id not in revision_ids:
                continue
            yield result

    def list_values_of(self, attr):
        """return a list of unique values of the specified attribute
        of PerfResult objects"""
        return dict.fromkeys((getattr(r, attr) for r in self.results)).keys()

    def get_testid2collections(self):
        """return a mapping of test_id to list of PerfResultCollection
        sorted by revision"""
        
        test_ids = self.list_values_of('test_id')
       
        testid2resultcollections = {}
        for test_id in test_ids:
            revnos = {}
            for result in self.get_results(test_ids=[test_id]): 
                revnos.setdefault(result.revision, []).append(result)
            for revno, results in revnos.iteritems():
                collection = PerfResultCollection(results)
                l = testid2resultcollections.setdefault(test_id, [])
                l.append(collection)
        # sort collection list by revision number
        for collections in testid2resultcollections.itervalues():
            collections.sort(lambda x,y: cmp(x.revision, y.revision))
        return testid2resultcollections
