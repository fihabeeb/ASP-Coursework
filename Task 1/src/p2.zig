const std = @import("std");
const context = @import("context.zig");

var c1: context.Context = undefined;
var c2: context.Context = undefined;

fn foo() void {
    std.debug.print("You called Foo\n", .{});
    context.set(&c2);
    std.debug.print("Changed Context\n", .{});
    //std.process.exit(1);
}

fn goo() void {
    std.debug.print("You called goo\n", .{});
    std.process.exit(33);
}

pub fn main() !void {
    var x: u8 = 0;

    var data: [4096]u8 = undefined;

    var sp = @intFromPtr(&data);

    var sp2 = @intFromPtr(&data);

    sp = sp + 4096;

    sp2 = sp2 + 4096;

    sp = sp & ~@as(usize, 15);

    sp = sp - 128; // @as(usize, 128);

    sp2 = sp2 & ~@as(usize, 15);

    sp2 = sp2 - 128;

    //_ = context.get(&c);

    c1.rip = @ptrCast(@constCast(&foo));

    c1.rsp = @ptrCast(@constCast(&sp));

    c2.rip = @ptrCast(@constCast(&goo));

    c2.rsp = @ptrCast(@constCast(&sp2));

    if (x == 0) {
        x = x + 1;
        context.set(&c1);
    }
}
