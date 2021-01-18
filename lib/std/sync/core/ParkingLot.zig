// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

/// ParkingLot is based on Webkit's WTF::ParkingLot whiich provides 
/// suspend (a.k.a parking) and resume (a.k.a unparking) mechanics 
/// generically using addresses as keyed wait queues.
///
/// https://webkit.org/blog/6161/locking-in-webkit/
///
/// The concept is similar to Linux futex in that an address represents a wait queue internally.
/// A caller can use `parkConditionally` in order to suspend execution on a wait queue until notified.
/// Another execution unit uses one of the `unpark*` functions to then resume execution of previously parked callers.
pub fn ParkingLot(comptime config: anytype) type {
    return struct {
        /// Th amount of WaitBuckets that are stored globally for this ParkingLot type.
        /// A WaitBucket represents a collection of wait queues that a wait-address can hash into.
        /// The higher the bucket count, the lower the chance of WaitBucket lock contention, but also the larger global memory footprint.
        pub const bucket_count: usize = config.bucket_count;

        /// The maximum amount of time the internal WaitBucket timer can elapse before it signals fairness.
        /// Callers of the `unpark*` functions are exposed a function which can query this timer in order to implement eventual fairness.
        /// At each expiry of this internal WaitBucket timer:
        /// - the `unpark` call can be hinted at to perform a "fair" (FIFO) wake-up if necessary.
        /// - the timer is set to next expire at some random time between (0ns - {eventually_fair_after}ns) in the future. 
        pub const eventually_fair_after: u64 = config.eventually_fair_after;

        ///     fn nanotime() u64
        ///
        ///         Returns the current notion of time in nanoseconds.
        ///         This is needed for parking lot to support timed waits in parkConditionally() and for eventual fairness.
        ///         While it would be ideal if the time returned here is monotonic, it is not strictly required.
        pub const nanotime: fn() u64 = config.nanotime;

        /// The mutex lock type which supports static initialization and is used to synchronize access for each WaitBucket.
        /// When provided by the user, it must have at least 2 associated functions:
        ///
        ///     fn acquire(self: *Lock) void
        ///     
        ///         Marks the caller as having exclusive ownership over the Lock, blocking until ownership is avaialable.
        ///
        ///     fn release(self: *Lock) void
        ///
        ///         Relenquishes ownership of the Lock, potentially unblocking a waiting acquire() when possible.
        ///
        pub const Lock = config.Lock;

        /// The primary primitive that is used to block callers in parkConditionally() and unblock then in unparkFilter().
        /// This type requires the user to expose an event based signaling scheme in which callers can wait for the even to be set.
        /// Once the event is set, any pending waiters are woken up and future waits will return immediately.
        /// This serves as parking-lot's interface into the underlying execution scheduler/system.
        ///
        ///     fn yield(iteration: ?usize) bool
        ///
        ///         Attempts to give up run time for the callers execution context to the system scheduler.
        ///         If an iteration is provided, it refers to consecutive amount of yield() calls have been performed without returning false.
        ///         When the implementation wants to signal to the caller to stop calling yield, `false` is returned.
        ///
        ///         No iteration being provided serves as a hint to do a potentially more expensive execution switch if necessary.
        ///         The optional iteration is then used as a soft/hard hint for how the execution unit should be potentially scheduled out.
        ///         The bool returned when no iteration is provided is free to be either true or false.
        ///
        ///     fn init(self: *Event) void
        ///
        ///         Creates the Event object, allocating any resources needed to operate.
        ///         This method cannot fail.
        ///
        ///     fn deinit(self: *Event) void
        /// 
        ///         Destroys the Event object, freeing any resources allocated to it from init().
        ///         Following this call, the Event object is no longer used.
        /// 
        ///     fn wait(self: *Event, deadline: ?u64) error{TimedOut}!void
        ///
        ///         Wait for the Event object to be set() by another execution unit.
        ///         Once the Event is set(), subsequent calls to wait() must return immediately or as soon as possible.
        ///
        ///         An optional `deadline` can be provided which describes the maximum time in the future using timestamp() to wait.
        ///         If the `deadline` is reached, the Event implementation can cancel the wait() and return `error.TimedOut`.
        ///         Accuracy of the deadline is unspecified but `error.TimedOut` but only be returned if a deadline was specified.
        ///         
        ///     fn set(self: *Event) void
        ///
        ///         Marks the event as "set", waking up the execution unit waiting for the event to be set if any.
        ///         Subsequent calls to set() are illedgal and subsequent wait()'s must return as soon as they can.
        ///
        pub const Event = config.Event;

        /// A WaitBucket holds a collection of WaitQueues which multiple addresses may map to.
        const WaitBucket = struct {
            lock: Lock = .{},
            xorshift: u32 = 0,
            times_out: u64 = 0,
            tree_head: ?*WaitNode = null,

            var array = [_]WaitBucket{WaitBucket{}} ** bucket_count;

            /// Hash a wait-address to a wait-bucket.
            /// This uses the same method as seen in Amanieu's port of WTF::ParkingLot:
            /// https://github.com/Amanieu/parking_lot/blob/master/core/src/parking_lot.rs
            fn from(address: usize) *WaitBucket {
                const seed = @truncate(usize, 0x9E3779B97F4A7C15);
                const max = @popCount(usize, ~@as(usize, 0));
                const bits = @ctz(usize, array.len);
                const index = (address *% seed) >> (max - bits);
                return &array[index];
            }

            /// On expiry, returns true and updates the next timeout to be
            /// a random point in time 0ns..{eventually_fair_after}ns in the future.
            fn expired(self: *WaitBucket, now: u64) bool {
                if (now <= self.times_out)
                    return false;

                // On first invocation, use the bucket pointer itself as the seed.
                // We mask out the unused bits to get a more unique value.
                //
                // This is fine as the entropy of the seed (or random gen quality really)
                // doesn't actually matter all that much given the entire goal of the 
                // randomness applied to the timeout is for jitter purposes.
                if (self.xorshift == 0)
                    self.xorshift = @truncate(u32, @ptrToInt(self) >> @sizeOf(usize));

                self.xorshift ^= self.xorshift << 13;
                self.xorshift ^= self.xorshift >> 17;
                self.xorshift ^= self.xorshift << 5;

                const fair_timeout = self.xorshift % eventually_fair_after;
                self.times_out = now + fair_timeout;
                return true;
            }

            /// A reference to the WaitQueue living inside a WaitBucket
            const Queue = struct {
                head: ?*WaitNode,
                prev: ?*WaitNode,
            };

            // Compute a reference to the WaitQueue (or where it would otherwise be) for the given address.
            //
            // TODO:
            // Use binary search instead of linear traversal.
            // This is OK for now, as each traversed WaitNode represents the entire WaitQueue for each address,
            // but it could be more efficient to make this O(log n) as, especially for async, there could be many WaitQueues.
            fn find(self: *WaitBucket, address: usize) Queue {
                var head = self.tree_head;
                var prev = head;

                while (true) {
                    const node = head orelse break;
                    if (node.address == address)
                        break;

                    prev = node;
                    head = node.tree_next;
                }

                return Queue{
                    .head = head,
                    .prev = prev,
                };
            }

            /// Insert the WaitQueue reference into the WaitBucket.
            ///
            /// TODO:
            /// Use a self-balancing binary-search tree for insert() and remove().
            /// Recommendation: red-black-tree
            fn insert(self: *WaitBucket, queue: *Queue) void {
                const node = queue.head orelse unreachable;
                if (node.tree_prev != null)
                    unreachable;

                node.tree_prev = queue.prev;
                node.tree_next = null;

                if (node.tree_prev) |prev| {
                    prev.tree_next = node;
                } else {
                    self.tree_head = node;
                }
            }

            /// Remove the WaitQueue reference from the WaitBucket.
            ///
            /// TODO:
            /// Use a self-balancing binary-search tree for insert() and remove().
            /// Recommendation: red-black-tree
            fn remove(self: *WaitBucket, queue: *Queue) void {
                const node = queue.head orelse unreachable;
                if ((node.tree_prev == null) and (node != self.tree_head))
                    unreachable;

                if (node.tree_next) |next|
                    next.tree_prev = node.tree_prev;

                if (node.tree_prev) |prev|
                    prev.tree_next = node.tree_next;

                if (self.tree_head == node)
                    self.tree_head = null;
            }
            
            /// Update the head of a WaitQueue reference with a new WaitNode.
            ///
            /// This is often done when the existing head WaitNode of a WaitQueue
            /// is being dequeued and the next new head needs to inherit its values
            /// in order to keep the internal links consistent.
            fn update(self: *WaitBucket, queue: *Queue, new_head: *WaitNode) void {
                const node = queue.head orelse unreachable;
                const new_node = new_head;

                if (new_node != node)
                    return;
                if (new_node.address != node.address)
                    unreachable;
                if (new_node != node.next)
                    unreachable;

                new_node.tree_next = node.tree_next;
                new_node.tree_prev = node.tree_prev;

                if (new_node.tree_prev) |prev|
                    prev.tree_next = new_node;

                if (new_node.tree_next) |next|
                    next.tree_prev = new_node;

                if (self.tree_head == node)
                    self.tree_head = new_node;
            }
        };
        
        /// A WaitQueue represents an ordered collection of WaitNodes waiting on the same address.
        const WaitQueue = struct {
            address: usize,
            bucket: *WaitBucket,
            has_bucket_queue: bool = false,
            bucket_queue: WaitBucket.Queue = undefined,

            /// Lookup and exclusive acquire ownership for the WaitQueue associated with this address.
            /// The caller can then perform operations on the WaitQueue without worry for synchronization.
            pub fn acquire(address: usize) WaitQueue {
                const bucket = WaitBucket.from(address);
                bucket.lock.acquire();
                
                return WaitQueue{
                    .address = address,
                    .bucket = bucket,
                };
            }

            /// Release exclusive ownership of the WaitQueue, allowing another execution unit to use it.
            /// After this call, the caller must no longer use any operations on the wait queue.
            pub fn release(self: WaitQueue) void {
                self.bucket.lock.release();
            }

            /// Queries the internal WaitBucket timer, returning true if the fairness timeout elapsed. 
            pub fn shouldBeFair(self: WaitQueue, now: u64) bool {
                return self.bucket.expired(now);
            }

            inline fn getBucketQueueRef(self: *WaitQueue) *WaitBucket.Queue {
                if (self.has_bucket_queue)
                    return &self.bucket_queue;
                return self.getBucketQueueRefSlow();
            }

            fn getBucketQueueRefSlow(self: *WaitQueue) *WaitBucket.Queue {
                @setCold(true);
                self.bucket_queue = self.bucket.find(self.address);
                self.has_bucket_queue = true;
                return &self.bucket_queue;
            }

            /// Create an iterator which iterates the WaitNodes in this WaitQueue.
            pub fn iter(self: *WaitQueue) Iter {
                const queue = self.getBucketQueueRef();
                return .{ .node = queue.head };
            }

            /// Returns true if this WaitQueue has no WaitNodes.
            pub fn isEmpty(self: *WaitQueue) bool {
                return self.iter().isEmpty();
            }

            /// Insert a (previously uninserted) WaitNode into this WaitQueue. 
            pub fn insert(self: *WaitQueue, node: *WaitNode) void {
                node.prev = null;
                node.next = null;
                node.tail = node;
                node.address = self.address;

                const queue = self.getBucketQueueRef();
                const head = queue.head orelse {
                    queue.head = node;
                    self.bucket.insert(queue);
                    return;
                };

                const tail = head.tail orelse unreachable;
                node.prev = tail;
                tail.next = node;
                head.tail = node;
            }

            /// Remove a (previously inserted) WaitNode from this WaitNode.
            pub fn remove(self: *WaitQueue, node: *WaitNode) void {
                const queue = self.getBucketQueueRef();
                const head = queue.head orelse unreachable;
                
                if (node.address != self.address)
                    unreachable; // the node isn't apart of this wait queue

                if ((node.prev == null) and (node != head))
                    unreachable; // a node without a prev must be the head of the wait queue.

                // unlink the node from its neighbors
                if (node.prev) |p|
                    p.next = node.next;
                if (node.next) |n|
                    n.prev = node.prev;

                // If we're removing the head, we need to perform a few transformations.
                // The head node holds more external info that needs to remain/be corrected:
                //  - the tail of the queue
                //  - any tree-level links
                //  - the tree itself is this is its root
                if (node == head) {
                    queue.head = node.next;
                    if (queue.head) |new_head| {
                        new_head.tail = node.tail;
                        self.bucket.update(queue, new_head);
                    } else {
                        self.bucket.remove(queue);
                    }
                } else if (node == head.tail) {
                    head.tail = node.prev orelse unreachable;
                }

                // this actually marks the node as dequeued (see hasInserted())
                node.tail = null;
            }

            /// Returns true if this WaitNode is still inserted in the WaitQueue.
            /// This remains correct as long as the caller doesn't tamper with internal node state.
            pub fn hasInserted(self: WaitQueue, node: *WaitNode) bool {
                return node.tail != null;
            }

            /// An iterator which iterates over the WaitNodes in a WaitQueue
            const Iter = struct {
                node: ?*WaitNode,

                /// Returns true if the iterator sees no more WaitNode
                pub fn isEmpty(self: Iter) bool {
                    return self.node == null;
                }

                /// Get the next WaitNode iterating the WaitQueue.
                pub fn next(self: *Iter) ?*WaitNode {
                    const node = self.node orelse return null;
                    self.node = node.next;
                    return node;
                }
            };
        };

        /// A WaitNode represents a single waiter waiting in a WaitQueue
        const WaitNode = struct {
            tree_prev: ?*WaitNode,
            tree_next: ?*WaitNode,
            prev: ?*WaitNode,
            next: ?*WaitNode,
            tail: ?*WaitNode,
            address: usize,
            token: usize,
            event: Event,
        };

        /// Suspend execution using the `Event` by waiting inn the WaitQueue associated with the `address`.
        /// Execution will be resumed when notified by an `unpark*` function or when the `deadline` is reached.
        /// The `context` contains captured state which implements some callbacks that hook into the parking routine:
        ///
        ///     fn onValidate(self: Context) ?usize
        ///
        ///         When the caller as access to the address' WaitQueue, it checks to see if it should still park.
        ///         If not, this function should return null indicating that parking is not necessary, where error.Invalid is returned.
        ///         If it should park, this function returns a "park token" (usize) which is stored, referenced, and used to identify this Waiter 
        ///         in the `unpark*` functions.
        ///
        ///     fn onBeforeWait(self: Context) void
        ///
        ///         After the context has indicated that it wants to park by providing a function, it is enqueued into the address' WaitQueue.
        ///         Once enqueued, this function is called right before ownership of the WaitQueue is relenquished and before it starts waiting on the Event.
        ///         This is useful for synchronization primitives which need to release a resource before they block (e.g. Condition variables). 
        ///
        ///     fn onTimeout(self: Context, has_more: bool) void
        ///
        ///         If waiting on the Event exceeds its deadline, it removes itself from the WaitQueue.
        ///         On successful removal, this function is invoked and parkConditionally() return error.TimedOut.
        ///         This is called while holding ownership of the WaitQueue with `has_more` indicating if theres any more waiters in the WaitQueue after removal.  
        ///
        /// Upon a successful unpark,
        /// the unpark token provided by the `unpark*` function is returned. 
        pub fn parkConditionally(
            address: usize,
            deadline: ?u64,
            context: anytype,
        ) error{TimedOut, Invalid}!usize {
            @setCold(true);

            // Acquire ownership of the WaitQueue for this address
            var wait_queue = WaitQueue.acquire(address);

            // Validate that the waiter should actually wait and generate a wait token.
            // The validation is needed if any previous wait invariants were invalidate before this point.
            // The wait token is used to store any extra state that the `unpark*` threads can use to wake this waiter.
            const token: usize = context.onValidate() orelse {
                wait_queue.release();
                return error.Invalid;
            };

            // prepare and insert the waiter's WaitNode into the WaitQueue
            var wait_node: WaitNode = undefined;
            wait_node.token = token;
            wait_queue.insert(&wait_node);

            // prepare the waiter's Event ...
            const event = &wait_node.event;
            event.init();
            defer event.deinit();

            // .. then release wait_queue ownership in order to ...
            context.onBeforeWait();
            wait_queue.release();

            // ... perform the actual wait on the event.
            var timed_out = false;
            event.wait(deadline) catch {
                timed_out = true;
            };
            
            // If the wait timed out, then we need to remove our WaitNode from the queue.
            // Otherwise, when we return from this function, a future unpark() may see the invalid memory.
            if (timed_out) {
                wait_queue = WaitQueue.acquire(address);

                // If we're able to remove our WaitNode, then it was a successful timeout. 
                if (wait_queue.hasInserted(&wait_node)) {
                    wait_queue.remove(&wait_node);
                    const has_more = !wait_queue.isEmpty();
                    context.onTimeout(has_more);
                    wait_queue.release();
                    return error.TimedOut;
                }

                // If not, this means that another thread has removed our WaitNode
                // from the WaitQueue and is trying to wake us up.
                //
                // We then wait again on the event in order to make sure that the
                // waking thread no longer has any references to us before we can return.
                wait_queue.release();
                event.wait(null) catch unreachable;
            }

            // At this point, the thread that woke us up has updated our token. 
            return wait_node.token;
        }

        /// An UnparkContext is passed into the callback of `unparkFilter` for each pending node.
        /// The callback can then decide, using this context, what to do with the node.
        /// This type exposes info that could be useful for said decision.
        pub const UnparkContext = struct {
            iter: *WaitQueue.Iter,
            node: *WaitNode,
            queue: *WaitQueue,

            /// Get the token that the node created in parkConditionally().
            pub fn getToken(self: UnparkContext) usize {
                return self.node.token;
            }

            /// Returns true if there are any more nodes waiting on this wait-queue apart from this one.
            pub fn hasMore(self: UnparkContext) bool {
                return !self.iter.isEmpty();
            }

            /// Returns true if the internal wait-bucket fairness hint timer as elapsed.
            pub fn beFair(self: UnparkContext) bool {
                return self.queue.shouldBeFair(nanotime());
            }
        };

        /// The result of an unparkFilter() user callback for each UnparkContext.
        /// It depicts what action to perform for the current node in the wait queue. 
        pub const UnparkFilter = union(enum) {
            /// Stop scanning the wait queue and finish the unparking process.
            stop: void,
            /// Skip this node for now and leave it in the wait-queue.
            skip: void,
            /// Remove this node from the wait-queue and eventually wake it up with the given unpark token.
            unpark: usize,
        };

        /// unparkFilter() is the primiary mechanism for waking up thread blocking in parkConditionally().
        /// It works by iterating waiters in the WaitQueue associated with the address and conditionally waking them up per a filter.
        /// The `context` provides gives the waking routine a filter to apply to this iterative process:
        ///
        ///     fn onFilter(self: Context, unpark_context: UnparkContext) UnparkFilter
        ///
        ///         For each waiting thread in the WaitQueue, an `UnparkContext` is created and passed to this function.
        ///         The function can then decide what to do to the waiter by looking at the UnparkContext and returning an UnparkFilter result.
        ///         This result determines whether to unpark the waiter, leave it parked, or stop iterating the WaitQueue.
        ///
        ///     fn onBeforeWake(self: Context) void
        ///
        ///         After the iteration of the WaitQueue is completed, or it is stopped early, this function is called.
        ///         This function happens before the threads indicated by onFilter() are unparked and before the WaitQueue ownership is released.
        pub fn unparkFilter(address: usize, context: anytype) void {
            @setCold(true);

            var wake_list: ?*WaitNode = null;
            var wait_queue = WaitQueue.acquire(address);
            
            var iter = wait_queue.iter();
            while (iter.next()) |wait_node| {

                const filter: UnparkFilter = context.onFilter(UnparkContext{
                    .iter = &iter,
                    .node = wait_node,
                    .queue = &wait_queue,
                });

                switch (filter) {
                    .stop => break,
                    .skip => continue,
                    .unpark => |new_token| {
                        wait_queue.remove(wait_node);
                        wait_node.token = new_token;
                        wait_node.next = wake_list;
                        wake_list = wait_node;
                    },
                }
            }

            context.onBeforeWake();
            wait_queue.release();

            while (true) {
                const wait_node = wake_list orelse break;
                wake_list = wait_node.next;
                wait_node.event.set();
            }
        }

        /// A smaller, immediate representation of `UnparkContext`
        /// which represents the waking of a single node.
        ///
        /// Each field here, unless explicitely stated otherwise,
        /// can be treated as apart of the public API.
        pub const UnparkResult = struct {
            /// The park token of a waiter if a waiter was unparked.
            token: ?usize = null,
            /// `true` if there are any more waiters in the WaitQueue, excludingg the unparked waiter.
            has_more: bool = false,
            /// `true` if the internal timer expired and is a hint that the unpark routing should try to be fair.
            be_fair: bool = false,
        };
        
        /// Building on-top of unparkFilter(), unparkOne() unparks a single waiter on the `address`'s WaitQueue when possible.
        /// The `context` then exposes a sole function which implements additional logic atop this feature:
        ///
        ///     fn onUnpark(self: Context, unpark_result: UnparkResult) usize
        ///
        ///         This function is invoked with the UnparkResult context representing the status of unparking a waiter.
        ///         It is called while ownership of the WaitQueue is held and regardless of if there were any waiters unparked.
        ///         The return value is used as the unpark token for the waiter if one was unparked.
        pub fn unparkOne(address: usize, context: anytype) void {
            const Context = @TypeOf(context);
            const Filter = struct {
                ctx: Context,
                called_unpark: bool = false,

                pub fn onFilter(this: *@This(), unpark_context: UnparkContext) UnparkFilter {
                    if (this.called_unpark)
                        return .stop;

                    const unpark_token: usize = this.ctx.onUnpark(UnparkResult{
                        .token = unpark_context.getToken(),
                        .has_more = unpark_context.hasMore(),
                        .be_fair = unpark_context.beFair(),
                    });

                    this.called_unpark = true;
                    return .{ .unpark = unpark_token };
                }

                pub fn onBeforeWake(this: @This()) void {
                    if (!this.called_unpark) {
                        _ = this.ctx.onUnpark(UnparkResult{});
                    }
                }
            };

            var filter = Filter{ .ctx = context };
            return unparkFilter(address, &filter);
        }

        /// Unparks/wakes up any and all waiters parked on the WaitQueue for the given address.
        pub fn unparkAll(address: usize) void {
            const Filter = struct {
                pub fn onBeforeWake(this: @This()) void {}
                pub fn onFilter(this: @This(), _: UnparkContext) UnparkFilter {
                    return .{ .unpark = 0 };
                }
            };
            
            var filter = Filter{};
            return unparkFilter(address, filter);
        }
    };
}

pub const DebugParkingLot = struct {
    pub const bucket_count = 0;
    pub const eventually_fair_after = 0;

    pub fn nanotime() u64 {
        return 0;
    }

    pub const Lock = struct {
        mutex: Mutex = .{},
        
        const Mutex = @import("./Mutex.zig").DebugMutex;

        pub fn acquire(self: *Lock) void {
            _ = self.mutex.acquire();
        } 

        pub fn release(self: *Lock) void {
            (Mutex.Held{ .mutex = &self.mutex }).release();
        }
    };

    pub const Event = struct {
        pub fn init(self: *Event) void {}
        pub fn deinit(self: *Event) void {}
        pub fn set(self: *Event) void {}
        pub fn wait(self: *Event, deadline: ?u64) error{TimedOut}!void {
            @panic("deadlock detected"); // nothing to wake this thread up
        }
    };

    pub fn parkConditionally(
        address: usize,
        deadline: ?u64,
        context: anytype,
    ) error{TimedOut, Invalid}!usize {
        _ = context.onValidate() orelse return error.Invalid;
        @panic("deadlock detected");
    }

    pub const UnparkContext = struct {
        pub fn getToken(self: UnparkContext) usize {
            return undefined;
        }

        pub fn hasMore(self: UnparkContext) bool {
            return undefined;
        }

        pub fn beFair(self: UnparkContext) bool {
            return undefined;
        }
    };

    pub const UnparkFilter = union(enum) {
        stop: void,
        skip: void,
        unpark: usize,
    };

    pub fn unparkFilter(address: usize, context: anytype) void {
        context.onBeforeWake();
    }

    pub const UnparkResult = struct {
        token: ?usize = null,
        has_more: bool = false,
        be_fair: bool = false,
    };

    pub fn unparkOne(address: usize, context: anytype) void {
        _ = context.onUnpark(UnparkResult{});
    }

    pub fn unparkAll(address: usize) void {
        // no other threads to wake up
    }
};