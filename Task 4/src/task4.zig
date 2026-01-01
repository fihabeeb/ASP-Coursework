const std = @import("std");
const context = @import("context.zig");
const deque = @import("deque.zig");

var s: *Scheduler = undefined;

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

        //issue p1, was &data
        var sp = @intFromPtr(data.ptr);

        sp = sp + 4096;

        sp = sp & ~@as(usize, 15);

        sp = sp - 128;

        tempContext.rip = @ptrCast(@constCast(function));
        //issue p2, was @ptrCast(@constCast(sp))
        tempContext.rsp = @ptrFromInt(sp);

        fiber.* = .{ .allocator = allocator, .context_ = tempContext, .stack_top = @ptrFromInt(sp), .data_ = data, .numberPointer_ = numPointer };

        return fiber;
    }

    pub fn deinit(self: Fiber) void {
        self.allocator.free(self.data_);
    }

    pub fn get_context(self: *Self) *context.Context {
        return &self.context_;
    }

    //pub fn save_yield_context(self: *Self) void {
    //    _ = context.get(&self.context_);
    //}
};

const Scheduler = struct {
    fibers_: std.ArrayList(*Fiber),
    context_: context.Context,
    allocator_: std.mem.Allocator,
    currentFiber_: ?*Fiber,
    fiberNumber_: *u8,

    pub fn init(allocator: std.mem.Allocator) !Scheduler {
        return Scheduler{ .fibers_ = .{}, .context_ = undefined, .allocator_ = allocator, .currentFiber_ = undefined, .fiberNumber_ = undefined };
    }

    pub fn deinit(self: Scheduler) void {
        self.fibers_.deinit(self.allocator_);
    }

    pub fn spawn(self: *Scheduler, f: *Fiber) !void {
        try self.fibers_.append(self.allocator_, f);
    }

    pub fn do_it(self: *Scheduler) void {
        _ = context.get(&self.context_);

        if (self.fibers_.items.len > 0) {
            self.currentFiber_ = self.fibers_.orderedRemove(0);
            self.fiberNumber_ = self.currentFiber_.?.numberPointer_;
            const c4: *context.Context = self.currentFiber_.?.get_context();
            context.set(c4);
        }
    }

    pub fn fiber_exit(self: *Scheduler) void {
        context.set((((&self.context_))));
    }

    pub fn get_data(self: *Scheduler) *u8 {
        return self.fiberNumber_;
    }

    pub fn yield(self: *Scheduler) void {
        //self.currentFiber_.?.save_yield_context();
        self.spawn(self.currentFiber_.?) catch {
            std.debug.print("messed up\n", .{});
        };
        const c = self.currentFiber_.?.get_context();
        self.currentFiber_ = null;
        context.swap(c, &self.context_);
    }
};

fn foo() void {
    std.debug.print("Foo start\n", .{});
    const num = s.get_data();
    s.yield();
    std.debug.print("Foo says: {d}\n", .{num.*});
    num.* = num.* + 1;
    s.fiber_exit();
}

fn goo() void {
    std.debug.print("Goo start\n", .{});
    s.yield();
    const num = s.get_data();
    std.debug.print("Goo says: {d}\n", .{num.*});
    s.fiber_exit();
}

fn moo() void {
    std.debug.print("Mooo start\n", .{});
    s.fiber_exit();
}

const allocatorInstance = std.heap.c_allocator;
const mem = allocatorInstance;
var d: u8 = 10;
const dp: *u8 = &d;
pub fn main() !void {}

test "initScheduler" {
    s = try allocatorInstance.create(Scheduler);
    s.* = try Scheduler.init(mem);
}

var f2: *Fiber = undefined;
var f1: *Fiber = undefined;
test "createFiber" {
    f2 = try Fiber.init(mem, @ptrCast(@constCast(&goo)), undefined, dp);
    f1 = try Fiber.init(mem, @ptrCast(@constCast(&foo)), undefined, dp);
}

test "makeSpawn" {
    try s.spawn(f1);
    try s.spawn(f2);
}

test "schedulerRun" {
    s.do_it();
}

test "changeDP" {
    try std.testing.expectEqual(dp.*, 11);
}
