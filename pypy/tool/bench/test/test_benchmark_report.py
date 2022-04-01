import os
import py

try:
    import Image
except ImportError as e:
    py.test.skip(str(e))

from pypy.tool.bench.htmlreport import (
        PerfResult, PerfTable, PerfResultCollection,
        PerfResultDelta, Page
)

# Sample performance data with a newline 
testlines = """\
--date 1152625530.0  hacker@canonical.com-20060705122759-0a3481a4647b16dc
 100ms package.module.test_name1

 200ms package.module.test_name2

""".splitlines()

class TestPerfTable:
    """tests to ensure that performance data files are processed properly"""
    
    def setup_method(self, method):
        self.lines = testlines[:]
        self.num_test_ids = 2

    def test_parse(self):
        """read one line and ensure the data is read correctly"""
        lines = self.lines[:2]
        t = PerfTable()
        data = list(t.parse(lines))
        assert len(data) == 1 # check that one object was created
        
        assert isinstance(data[0], PerfResult) # is it really a PerfResult
        pr = data[0]
        expected = PerfResult(
            date=1152625530.0,
            revision_id='hacker@canonical.com-20060705122759-0a3481a4647b16dc',
            elapsed_time=100,
            test_id=('package.module.test_name1'),
        )
        assert pr.test_id == expected.test_id
        assert pr.revision_id == expected.revision_id
        assert pr.elapsed_time == expected.elapsed_time
        assert pr.date == expected.date

    def test_multiline_parse(self):
        """ensure all lines are parsed correctly. """
        
        lines= self.lines
        results = list(PerfTable().parse(lines))
        assert len(results) == self.num_test_ids # was all data read?
        assert len(dict.fromkeys([r.revision_id for r in results])) == (
                          1) # check for one unique revision id

        # check for self.num_test_ids unique test ids
        assert len(dict.fromkeys([r.test_id for r in results])) == ( 
                          self.num_test_ids) 

    def test_get_results(self):
        """check that get_results returns the right number of PerfResults"""

        perftable = PerfTable()
        perftable.add_lines(self.lines)
        results = list(perftable.get_results())
        assert len(results) == self.num_test_ids
        test_ids = perftable.list_values_of('test_id')
        # check that get_result returns all results for an empty test_id argument
        assert list(perftable.get_results()) == (
                          list(perftable.get_results(test_ids = test_ids)))
        # check that get_results returns only the requested (number of) results
        results = list(perftable.get_results(test_ids = test_ids[1:]))
        assert len(results) == self.num_test_ids -1

        
    def test_get_results_two_dates_same_revision_id(self):
        """check that PerfTable handles 2 dates in the data correctly"""

        # generate a second block of performance history data
        # with the same length as the first block
        new_date = float(self.lines[0].split(None, 2)[1]) + 1
        new_line = '%s %s %s' % (
            self.lines[0].split(None, 2)[0],
            new_date,
            self.lines[0].split(None, 2)[2],
        )
        lines = [new_line] + self.lines[1:] + self.lines

        perftable = PerfTable(lines)
        results = list(perftable.get_results())
        assert len(results) == 2* self.num_test_ids

        # get results for one (test_id, revision_id) pair
        # and check that get_result returns a result object for each date
        test_ids = perftable.list_values_of('test_id')[:1]
        revision_ids = perftable.list_values_of('revision_id')[:1]
        results = list(perftable.get_results(test_ids = test_ids,
                                             revision_ids = revision_ids))
        assert len(results) == 1+1
        r0 = results[0]
        r1 = results[1]
        assert r0 != r1
        #check that r0 and r1 are equal, except the date is different
        r0.date = r1.date = None
        assert r0.test_id == r1.test_id


    def test_list_values_of(self):
        perftable = PerfTable(self.lines)
        assert perftable.list_values_of('date') == [1152625530.0]
        assert perftable.list_values_of('revision_id') == ( 
                     ['hacker@canonical.com-20060705122759-0a3481a4647b16dc'])
        assert len(perftable.list_values_of('test_id')) == (
                          self.num_test_ids)
        # check number of unique test ids
        assert len(dict.fromkeys(
                                perftable.list_values_of('test_id')).keys()) == 2


class TestPerfResultCollection:
    """check the average and variance computation"""
    
    def test_property_elapsed_time(self):
        """check elapsed_time computated property"""
        p1 = PerfResult(elapsed_time=1, date=132.123)
        p2 = PerfResult(elapsed_time=2, date=142.1)
        sample = PerfResultCollection([p1,p2])
        assert sample.min_elapsed == 1

    
class TestPerfResultDelta:
    """check delta computations and the statistical tests"""
    
    def setup_method(self, meth):
        self.r1 = PerfResult(date=123123.123, elapsed_time = 10)
        self.r2 = PerfResult(date=123523.123, elapsed_time = 11)
        self.c1 = PerfResultCollection([self.r1])
        self.c2 = PerfResultCollection([self.r2])

    def test_attributes(self):
        """check delta computation"""
        delta = PerfResultDelta(self.c1, self.c2)
        assert delta.delta == ( 
                          self.c2.min_elapsed - self.c1.min_elapsed)
        assert round(delta.percent - 0.10, 7) == 0

    def test_delta_is_computed_from_one_value_only(self):
        delta = PerfResultDelta(self.c1, None)
        assert delta.delta == 0
        assert delta.percent == 0.0
        
        delta = PerfResultDelta(None, self.c2)
        assert delta.delta == 0
        assert delta.percent == 0.0

        
class TestPage:
    """check that every part of the page and the page itself can be
    generated without errors"""
    
    def setup_method(self, method):
        self.lines = testlines[:]
        self.perftable = PerfTable(self.lines)
            
    def check_serialize_html(self, html):
        """render unicode string from the given 'html' tree.

        :html: pyxml html object tree
        """
        x = unicode(html)

    def test_gen_image_map(self):
        """check image map for 20 Perf Results"""
        samples = [
            PerfResultCollection(
                [PerfResult(
                        elapsed_time=i,
                        test_id='test_id',
                        revision_id='revision %s' % (i,),
                        revision=i
                    )
                ]
            ) for i in range(20)
        ]
        x = Page().gen_image_map(samples, revisions=range(20))
        self.check_serialize_html(x)
    
    def test_report(self):
        """check revision report showing changes to prev revision"""
        
        p1 = [PerfResultCollection([PerfResult(elapsed_time=i,
                                           date=float(i),
                                           revision = 1,
                                           test_id='test123',
                                           revision_id='one')])
              for i in range(1, 4)]
        p2 = [PerfResultCollection([PerfResult(elapsed_time=i, 
                                           date=float(i), 
                                           test_id='test123',
                                           revision = 2,
                                           revision_id='two')])
              for i in range(2, 5)]

        deltas = [PerfResultDelta(*pair) for pair in zip(p1, p2)]
        self.check_serialize_html(Page().render_report(deltas))

    def test_header(self):
        """check header generation"""
        p1 = PerfResultCollection([PerfResult(revision_date=124.8, 
                                            nick="hello",
                                            revision=100)])
        p2 = PerfResultCollection([PerfResult(revision_date=12456.3, 
                                            nick="hello",
                                            revision=200 )])
        self.check_serialize_html(Page().render_header(
                p1.results[0], p2.results[0]))
        
    def test_table(self):
        """check main reporting table generation"""
        p1 = PerfResultCollection(
            [PerfResult(
                    elapsed_time=2, 
                    revision_date=124.8, 
                    revision=100, 
                    test_id=('bzrlib.benchmarks.bench_add.AddBenchmark.'
                                'test_one_add_kernel_like_tree'),
                )
            ]
        )
        p2 = PerfResultCollection(
            [PerfResult(
                    elapsed_time=3, 
                    revision_date=12456.3, 
                    revision=200,
                    test_id=('bzrlib.benchmarks.bench_add.AddBenchmark.'
                                'test_one_add_kernel_like_tree'),
                ),
            ]
        )

        samples = [
            PerfResultCollection(
                [PerfResult(
                        elapsed_time=i,
                        test_id='test_id',
                        revision_id='revision%s' % (i,),
                        revision = i
                    ),
                ],
            ) for i in range(20)
        ]

        images = [Page().gen_image_map(samples, revisions=range(20))
                    for i in range(4)]

        d1 = [PerfResultCollection(
                [PerfResult(
                        elapsed_time=i,
                        date = 130.0,
                        test_id='test123',
                        revision=1,
                        revision_id='one',
                    ),
                ],
            ) for i in range(1, 4)
        ]
        d2 = [PerfResultCollection(
                [PerfResult(
                        elapsed_time=i,
                        date = 140.0,
                        test_id='test123',
                        revision=2,
                        revision_id='two',
                    ),
                ],
            ) for i in range(2, 5)
        ]
        deltas = [PerfResultDelta(*pair) for pair in zip(d1, d2)]
        p = Page().render_table(deltas, images)
        self.check_serialize_html(p)

    def test_page_rendering_on_sample_dataset(self):
        perftable = PerfTable(testdata.splitlines())
        page = Page(perftable).render()
        self.check_serialize_html(page)

testdata = """

--date 1151350547.87  pqm@pqm.ubuntu.com-20060626193547-43661d1377f72b4d
 2744ms bzrlib.benchmarks.bench_add.AddBenchmark.test_one_add_kernel_like_tree

 3406ms bzrlib.benchmarks.bench_bench.MakeKernelLikeTreeBenchmark.test_make_kernel_like_tree

13492ms bzrlib.benchmarks.bench_checkout.CheckoutBenchmark.test_build_kernel_like_tree

27762ms bzrlib.benchmarks.bench_commit.CommitBenchmark.test_commit_kernel_like_tree

  155ms bzrlib.benchmarks.bench_inventory.InvBenchmark.test_make_10824_inv_entries

   58ms bzrlib.benchmarks.bench_log.LogBenchmark.test_cmd_log

  338ms bzrlib.benchmarks.bench_log.LogBenchmark.test_cmd_log_subprocess

  393ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log

   54ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful

   37ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful_line

   26ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful_short

  687ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_verbose

   98ms bzrlib.benchmarks.bench_log.LogBenchmark.test_merge_log

  104ms bzrlib.benchmarks.bench_osutils.WalkDirsBenchmark.test_walkdirs_kernel_like_tree

  283ms bzrlib.benchmarks.bench_rocks.RocksBenchmark.test_rocks

 2222ms bzrlib.benchmarks.bench_status.StatusBenchmark.test_no_changes_known_kernel_like_tree

 1075ms bzrlib.benchmarks.bench_status.StatusBenchmark.test_no_ignored_unknown_kernel_like_tree

  510ms bzrlib.benchmarks.bench_transform.TransformBenchmark.test_canonicalize_path

  406ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_is_ignored_10824_calls

    3ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_is_ignored_single_call

  294ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_list_files_kernel_like_tree

 1081ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_list_files_unknown_kernel_like_tree

--date 1152797874.33  pqm@pqm.ubuntu.com-20060713133754-64c134fffd39fd99
 2588ms bzrlib.benchmarks.bench_add.AddBenchmark.test_one_add_kernel_like_tree

 3467ms bzrlib.benchmarks.bench_bench.MakeKernelLikeTreeBenchmark.test_make_kernel_like_tree

13637ms bzrlib.benchmarks.bench_checkout.CheckoutBenchmark.test_build_kernel_like_tree

28816ms bzrlib.benchmarks.bench_commit.CommitBenchmark.test_commit_kernel_like_tree

  207ms bzrlib.benchmarks.bench_inventory.InvBenchmark.test_make_10824_inv_entries

   54ms bzrlib.benchmarks.bench_log.LogBenchmark.test_cmd_log

  340ms bzrlib.benchmarks.bench_log.LogBenchmark.test_cmd_log_subprocess

  396ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log

   54ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful

   41ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful_line

   26ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful_short

  691ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_verbose

   98ms bzrlib.benchmarks.bench_log.LogBenchmark.test_merge_log

  105ms bzrlib.benchmarks.bench_osutils.WalkDirsBenchmark.test_walkdirs_kernel_like_tree

  280ms bzrlib.benchmarks.bench_rocks.RocksBenchmark.test_rocks

 2229ms bzrlib.benchmarks.bench_status.StatusBenchmark.test_no_changes_known_kernel_like_tree

 1309ms bzrlib.benchmarks.bench_status.StatusBenchmark.test_no_ignored_unknown_kernel_like_tree

  504ms bzrlib.benchmarks.bench_transform.TransformBenchmark.test_canonicalize_path

   31ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_is_ignored_10824_calls

    0ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_is_ignored_single_call

  294ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_list_files_kernel_like_tree

  380ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_list_files_unknown_kernel_like_tree

--date 1152818329.6  pqm@pqm.ubuntu.com-20060713191849-c0cbdf94d208fa69
 1982ms bzrlib.benchmarks.bench_add.AddBenchmark.test_one_add_kernel_like_tree

 3748ms bzrlib.benchmarks.bench_bench.MakeKernelLikeTreeBenchmark.test_make_kernel_like_tree

13696ms bzrlib.benchmarks.bench_checkout.CheckoutBenchmark.test_build_kernel_like_tree

28351ms bzrlib.benchmarks.bench_commit.CommitBenchmark.test_commit_kernel_like_tree

  207ms bzrlib.benchmarks.bench_inventory.InvBenchmark.test_make_10824_inv_entries

   53ms bzrlib.benchmarks.bench_log.LogBenchmark.test_cmd_log

  334ms bzrlib.benchmarks.bench_log.LogBenchmark.test_cmd_log_subprocess

  397ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log

   55ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful

   41ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful_line

   26ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful_short

  692ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_verbose

   99ms bzrlib.benchmarks.bench_log.LogBenchmark.test_merge_log

  107ms bzrlib.benchmarks.bench_osutils.WalkDirsBenchmark.test_walkdirs_kernel_like_tree

  281ms bzrlib.benchmarks.bench_rocks.RocksBenchmark.test_rocks

 2296ms bzrlib.benchmarks.bench_status.StatusBenchmark.test_no_changes_known_kernel_like_tree

 1119ms bzrlib.benchmarks.bench_status.StatusBenchmark.test_no_ignored_unknown_kernel_like_tree

  503ms bzrlib.benchmarks.bench_transform.TransformBenchmark.test_canonicalize_path

   30ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_is_ignored_10824_calls

    0ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_is_ignored_single_call

  507ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_list_files_kernel_like_tree

  353ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_list_files_unknown_kernel_like_tree

--date 1152977475.32  pqm@pqm.ubuntu.com-20060715153115-59f1601f31ecc38f
 1972ms bzrlib.benchmarks.bench_add.AddBenchmark.test_one_add_kernel_like_tree

 3512ms bzrlib.benchmarks.bench_bench.MakeKernelLikeTreeBenchmark.test_make_kernel_like_tree

13703ms bzrlib.benchmarks.bench_checkout.CheckoutBenchmark.test_build_kernel_like_tree

28276ms bzrlib.benchmarks.bench_commit.CommitBenchmark.test_commit_kernel_like_tree

  211ms bzrlib.benchmarks.bench_inventory.InvBenchmark.test_make_10824_inv_entries

   53ms bzrlib.benchmarks.bench_log.LogBenchmark.test_cmd_log

  333ms bzrlib.benchmarks.bench_log.LogBenchmark.test_cmd_log_subprocess

  397ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log

   56ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful

   41ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful_line

   26ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_screenful_short

  694ms bzrlib.benchmarks.bench_log.LogBenchmark.test_log_verbose

  100ms bzrlib.benchmarks.bench_log.LogBenchmark.test_merge_log

  110ms bzrlib.benchmarks.bench_osutils.WalkDirsBenchmark.test_walkdirs_kernel_like_tree

  271ms bzrlib.benchmarks.bench_rocks.RocksBenchmark.test_rocks

 2259ms bzrlib.benchmarks.bench_status.StatusBenchmark.test_no_changes_known_kernel_like_tree

 1548ms bzrlib.benchmarks.bench_status.StatusBenchmark.test_no_ignored_unknown_kernel_like_tree

  511ms bzrlib.benchmarks.bench_transform.TransformBenchmark.test_canonicalize_path

   30ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_is_ignored_10824_calls

    0ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_is_ignored_single_call

  296ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_list_files_kernel_like_tree

  387ms bzrlib.benchmarks.bench_workingtree.WorkingTreeBenchmark.test_list_files_unknown_kernel_like_tree
"""
