import pytest
from rpython.rlib import rvmprof
from rpython.rlib.rvmprof.test.support import FakeVMProf, fakevmprof

class TestFakeVMProf(object):

    def test_sampling(self):
        fake = FakeVMProf()
        assert not fake.is_sampling_enabled
        #
        fake.start_sampling()
        assert fake.is_sampling_enabled
        #
        fake.stop_sampling()
        fake.stop_sampling()
        assert not fake.is_sampling_enabled
        #
        fake.start_sampling()
        assert not fake.is_sampling_enabled
        fake.start_sampling()
        assert fake.is_sampling_enabled
        #
        pytest.raises(AssertionError, "fake.start_sampling()")
    
    def test_check_status(self):
        fake = FakeVMProf()
        fake.stop_sampling()
        pytest.raises(ValueError, "fake.check_status()")


class TestFixture(object):

    def test_fixture(self, fakevmprof):
        assert isinstance(fakevmprof, FakeVMProf)
        assert rvmprof._get_vmprof() is fakevmprof
        #
        # tweak sampling using the "real" API, and check that we actually used
        # the fake
        rvmprof.start_sampling()
        assert fakevmprof.is_sampling_enabled
        rvmprof.stop_sampling()
        assert not fakevmprof.is_sampling_enabled
