const std = @import("std");
const context = @import("context.zig");

pub const c = @cImport({
    @cInclude("foo.h");
});

const get_num = c.get_num;

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    //std.debug.print("Context for ASP\n", .{});

    var x: u8 = 0;
    var c1: context.Context = undefined;
    _ = context.get(&c1);
    std.debug.print("A message\n", .{});

    if (x == 0) {
        x = x + 1;
        context.set(&c1);
    }
}
