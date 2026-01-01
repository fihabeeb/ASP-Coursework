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

    pub fn init(allocator: std.mem.Allocator, function: *const fn () void, _context: context.Context, numPointer: *u8) !*Fiber {
        const fiber = try allocator.create(Fiber);

        var tempContext: context.Context = _context;

        var data = try allocator.alloc(u8, 4096);

        var sp = @intFromPtr(&data);

        sp = sp + 4096;

        sp = sp & ~@as(usize, 15);

        sp = sp - 128;

        tempContext.rip = @ptrCast(@constCast(function));
        tempContext.rsp = @ptrCast(@constCast(&sp));

        fiber.* = .{ .allocator = allocator, .context_ = tempContext, .stack_top = @ptrCast(@constCast(&sp)), .data_ = data, .numberPointer_ = numPointer };

        return fiber;

        //return Fiber{ .allocator = allocator, .context_ = tempContext, .stack_top = @ptrCast(@constCast(&sp)), .data_ = data, .numberPointer_ = numPointer };
    }

    pub fn deinit(self: Fiber) void {
        //_ = self;
        self.allocator.free(self.data_);
    }

    pub fn get_context(self: *Self) context.Context {
        //_ = context.get(&self.context_);
        return self.context_;
    }
};

const Scheduler = struct {
    //fibers_: deque.Deque(*Fiber),
    fibers_: std.ArrayList(*Fiber),
    context_: context.Context,
    allocator_: std.mem.Allocator,
    currentFiber_: *Fiber,
    fiberNumber_: *u8,

    pub fn init(allocator: std.mem.Allocator) !Scheduler {
        return Scheduler{ .fibers_ = .{}, .context_ = undefined, .allocator_ = allocator, .currentFiber_ = undefined, .fiberNumber_ = undefined };
    }

    pub fn deinit(self: Scheduler) void {
        self.fibers_.deinit(self.allocator_);
    }

    pub fn spawn(self: *Scheduler, f: *Fiber) !void {
        //try self.fibers_.pushBack(f);
        try self.fibers_.append(self.allocator_, f);
    }

    pub fn do_it(self: *Scheduler) void {
        _ = context.get(&self.context_);

        if (self.fibers_.items.len > 0) {
            self.currentFiber_ = self.fibers_.orderedRemove(0);
            self.fiberNumber_ = self.currentFiber_.numberPointer_;
            var c4: context.Context = self.currentFiber_.get_context();
            context.set(&c4);
        }
    }

    pub fn fiber_exit(self: *Scheduler) void {
        context.set((@ptrCast(@constCast(&self.context_))));
    }

    pub fn get_data(self: *Scheduler) *u8 {
        return self.fiberNumber_;
    }
};

fn foo() void {
    std.debug.print("Foo start\n", .{});
    const dp = s.get_data();
    std.debug.print("Foo says: {d}\n", .{dp.*});
    dp.* = dp.* + 1;
    s.fiber_exit();
    //std.process.exit(1);
}

fn goo() void {
    std.debug.print("Goo start\n", .{});
    const dp = s.get_data();
    std.debug.print("Goo says: {d}\n", .{dp.*});
    s.fiber_exit();
    //std.process.exit(3);
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;
    const mem = allocator;
    s = try Scheduler.init(mem);

    var d: u8 = 10;

    const dp: *u8 = &d;

    const f2 = try Fiber.init(mem, @ptrCast(@constCast(&goo)), undefined, dp);
    const f1 = try Fiber.init(mem, @ptrCast(@constCast(&foo)), undefined, dp);

    //try s.spawn(@ptrCast(@constCast(&f1)));
    //try s.spawn(@ptrCast(@constCast(&f2)));

    try s.spawn(f1);
    try s.spawn(f2);

    s.do_it();
}
