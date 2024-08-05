//! This module contains utility functions for working with error sets.

const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const Type = std.builtin.Type;

/// Returns whether ErrorSet contains all members of ErrorSetToCheckBeingFullyContained.
pub fn containsAll(comptime ErrorSet: type, comptime ErrorSetToCheckBeingFullyContained: type) bool {
    comptime assert(@typeInfo(ErrorSet) == .ErrorSet);
    comptime assert(@typeInfo(ErrorSetToCheckBeingFullyContained) == .ErrorSet);
    return (ErrorSet || ErrorSetToCheckBeingFullyContained) == ErrorSet;
}
test containsAll {
    comptime {
        assert(containsAll(error{ A, B }, error{ A, B }));
        assert(containsAll(anyerror, error{ A, B }));
        assert(containsAll(error{C}, error{C}));
        assert(!containsAll(error{C}, error{D}));
        assert(!containsAll(error{}, error{F}));
        assert(containsAll(error{}, error{}));
        assert(containsAll(anyerror, error{}));
        assert(containsAll(anyerror, anyerror));
    }
}
/// Returns whether ErrorSet contains error_to_check_being_contained.
pub fn contains(comptime ErrorSet: type, comptime error_to_check_being_contained: anyerror) bool {
    const ErrorToCheckBeingContained = @TypeOf(@field(anyerror, @errorName(error_to_check_being_contained)));
    return containsAll(ErrorSet, ErrorToCheckBeingContained);
}
test contains {
    comptime {
        assert(contains(error{ A, B, C }, error.B));
        assert(contains(anyerror, error.B));
        assert(!contains(error{ A, B, C }, error.D));
        assert(!contains(error{}, error.D));
    }
}

/// Returns the set of errors that are
/// members of BaseErrorSet, but not members of ToExcludeErrorSet.
/// ToExcludeErrorSet does not have to
/// be contained in, or even intersect BaseErrorSet.
/// See also `ExcludingAssertAllContained`.
pub fn Excluding(comptime BaseErrorSet: type, comptime ToExcludeErrorSet: type) type {
    if (BaseErrorSet == ToExcludeErrorSet) return error{}; //allows excluding anyerror from anyerror

    const base_info = @typeInfo(BaseErrorSet);
    comptime assert(base_info == .ErrorSet);
    const non_anyerror_base_info = base_info.ErrorSet.?; //Type.ErrorSet of null means anyerror, which is currently unsupported as BaseErrorSet
    comptime var remaining_error_count = 0;
    comptime var remaining_error_buffer: [non_anyerror_base_info.len]Type.Error = undefined;
    inline for (non_anyerror_base_info) |error_of_set| {
        if (comptime !contains(ToExcludeErrorSet, @field(anyerror, error_of_set.name))) {
            remaining_error_buffer[remaining_error_count] = error_of_set;
            remaining_error_count += 1;
        }
    }
    return @Type(.{ .ErrorSet = remaining_error_buffer[0..remaining_error_count] });
}
test Excluding {
    comptime {
        assert(Excluding(error{ A, B, C, D, E, F }, error{ B, C, E }) == error{ A, D, F });
        assert(Excluding(error{ A, B }, error{ B, D }) == error{A});
        assert(Excluding(error{ B, D }, error{ B, C, D, E }) == error{});
        assert(Excluding(error{ A, B, C, D, E, F }, anyerror) == error{});
        assert(Excluding(anyerror, anyerror) == error{});
        assert(Excluding(error{}, anyerror) == error{});
        assert(Excluding(error{ A, B }, error{}) == error{ A, B });
        assert(Excluding(error{}, error{}) == error{});
    }
}
/// Returns an error set with all members of BaseErrorSet
/// except for error_to_exclude.
/// error_to_exclude does not have to be a member of BaseErrorSet.
/// See also `WithoutAssertContained`.
pub fn Without(comptime BaseErrorSet: type, comptime error_to_exclude: anyerror) type {
    const ErrorSetToExclude = @TypeOf(@field(anyerror, @errorName(error_to_exclude)));
    return comptime Excluding(BaseErrorSet, ErrorSetToExclude);
}
test Without {
    comptime {
        assert(Without(error{ A, B, C }, error.B) == error{ A, C });
        assert(Without(error{ A, B }, error.A) == error{B});
        assert(Without(error{ A, B }, error.C) == error{ A, B });
        assert(Without(error{D}, error.D) == error{});
        assert(Without(error{}, error.A) == error{});
    }
}

/// Returns an error set with all errors which are
/// members of both ErrorSetA and ErrorSetB.
/// The resulting error set may be empty.
/// See also `IntersectAssertNonEmpty`.
pub fn Intersect(comptime ErrorSetA: type, comptime ErrorSetB: type) type {
    if (ErrorSetA == anyerror) return ErrorSetB; //allows intersecting with anyerror

    const base_info = @typeInfo(ErrorSetA);
    comptime assert(base_info == .ErrorSet);
    const non_anyerror_base_info = base_info.ErrorSet.?; //anyerror checked above
    comptime var remaining_error_count = 0;
    comptime var remaining_error_buffer: [non_anyerror_base_info.len]Type.Error = undefined;
    inline for (non_anyerror_base_info) |error_of_set| {
        if (comptime contains(ErrorSetB, @field(anyerror, error_of_set.name))) {
            remaining_error_buffer[remaining_error_count] = error_of_set;
            remaining_error_count += 1;
        }
    }
    return @Type(.{ .ErrorSet = remaining_error_buffer[0..remaining_error_count] });
}
test Intersect {
    comptime {
        assert(Intersect(error{ A, B }, error{ B, D }) == error{B});
        assert(Intersect(error{ B, D }, error{ B, C, D, E }) == error{ B, D });
        assert(Intersect(error{ A, E, F }, anyerror) == error{ A, E, F });
        assert(Intersect(anyerror, anyerror) == anyerror);
        assert(Intersect(error{}, anyerror) == error{});
        assert(Intersect(error{ A, B }, error{G}) == error{});
        assert(Intersect(error{}, error{}) == error{});
    }
}

/// Returns the set of errors that are
/// members of BaseErrorSet, but not members of ToExcludeErrorSet.
/// Asserts that all members of ToExcludeErrorSet are members of BaseErrorSet.
/// See also `Excluding`.
pub fn ExcludingAssertAllContained(comptime BaseErrorSet: type, comptime ToExcludeErrorSet: type) type {
    comptime assert(containsAll(BaseErrorSet, ToExcludeErrorSet));
    return comptime Excluding(BaseErrorSet, ToExcludeErrorSet);
}
/// Returns an error set with all members of BaseErrorSet
/// except for error_to_exclude.
/// Asserts that error_to_exclude is a member of BaseErrorSet.
/// See also `Without`.
pub fn WithoutAssertContained(comptime BaseErrorSet: type, comptime error_to_exclude: anyerror) type {
    comptime assert(contains(BaseErrorSet, error_to_exclude));
    return comptime Without(BaseErrorSet, error_to_exclude);
}
/// Returns an error set with all errors which are
/// members of both ErrorSetA and ErrorSetB.
/// Asserts that the resulting error set is not empty.
/// See also `Intersect`.
pub fn IntersectAssertNonEmpty(comptime ErrorSetA: type, comptime ErrorSetB: type) type {
    const Result = Intersect(ErrorSetA, ErrorSetB);
    comptime assert(Result != error{});
    return Result;
}
