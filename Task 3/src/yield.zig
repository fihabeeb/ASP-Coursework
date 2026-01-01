const std = @import("std");
const context = @import("context.zig");
const deque = @import("deque.zig");

var s: Scheduler = undefined;

const Fiber = struct {
    context_: context.Context,
    data_: []u8,
    stack_top: *u8,
    numberPointer_: *u8,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        function: *const fn () void,
        initial_context: context.Context,
        numPointer: *u8,
    ) !Fiber {
        var ctx = initial_context;

        // Allocate fiber stack
        var data = try allocator.alloc(u8, 4096);

        // Compute top-of-stack address
        var sp: usize = @intFromPtr(data.ptr) + data.len;

        // Align to 16 bytes
        sp &= ~@as(usize, 15);
        // Reserve red zone (128 bytes)
        sp -= 128;

        // Convert integer to pointer using new Zig rules:
        //const raw_ptr = @ptrFromInt(sp); // *allowzero u8
        //const rsp_ptr: *u8 = @ptrCast(@ptrFromInt(sp));

        // Install entry point + stack pointer
        ctx.rip = @ptrCast(@constCast(function));
        ctx.rsp = @ptrCast(@constCast(&sp));

        return Fiber{
            .allocator = allocator,
            .context_ = ctx,
            .stack_top = @ptrCast(@constCast(&sp)),
            .data_ = data,
            .numberPointer_ = numPointer,
        };
    }

    pub fn deinit(self: Fiber) void {
        self.allocator.free(self.data_);
    }

    pub fn get_context(self: *Self) *context.Context {
        return &self.context_;
    }
};

const Scheduler = struct {
    fibers_: deque.Deque(*Fiber),
    context_: context.Context,
    allocator_: std.mem.Allocator,
    currentFiber_: *Fiber,
    fiberNumber_: *u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .fibers_ = try deque.Deque(*Fiber).init(allocator),
            .context_ = undefined,
            .allocator_ = allocator,
            .currentFiber_ = undefined,
            .fiberNumber_ = undefined,
        };
    }

    pub fn deinit(self: Scheduler) void {
        _ = self;
    }

    pub fn spawn(self: *Self, f: *Fiber) !void {
        try self.fibers_.pushBack(f);
    }

    pub fn do_it(self: *Self) void {
        // Save scheduler context
        _ = context.get(&self.context_);

        if (self.fibers_.len() > 0) {
            self.currentFiber_ = self.fibers_.popFront().?;
            self.fiberNumber_ = self.currentFiber_.numberPointer_;

            // Switch to fiber context
            context.set(self.currentFiber_.get_context());
        }
    }

    pub fn fiber_exit(self: *Self) void {
        // Switch back to scheduler
        context.set(&self.context_);
    }

    pub fn yield(self: *Self) void {
        // Save fiber CPU registers
        _ = context.get(self.currentFiber_.get_context());

        // Requeue current fiber
        self.fibers_.pushBack(self.currentFiber_) catch {
            std.debug.print("scheduler yield(): pushBack failed\n", .{});
        };

        // Switch back to scheduler
        context.set(&self.context_);
    }

    pub fn get_data(self: *Self) *u8 {
        return self.fiberNumber_;
    }
};

// ----------------------------------------------------------
// Example fiber functions
// ----------------------------------------------------------

fn foo() void {
    std.debug.print("Foo step 1\n", .{});
    s.yield();
    std.debug.print("Foo step 2\n", .{});
    s.fiber_exit();
}

fn goo() void {
    std.debug.print("Goo step 1\n", .{});
    s.yield();
    std.debug.print("Goo step 2\n", .{});
    s.fiber_exit();
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    s = try Scheduler.init(allocator);

    var d: u8 = 10;
    const dp = &d;

    var f1 = try Fiber.init(allocator, &foo, undefined, dp);
    var f2 = try Fiber.init(allocator, &goo, undefined, dp);

    try s.spawn(&f1);
    try s.spawn(&f2);

    s.do_it();
}
