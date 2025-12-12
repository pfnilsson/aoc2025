const std = @import("std");
const helpers = @import("helpers");

const day01 = @import("days/day01.zig");
const day02 = @import("days/day02.zig");
const day03 = @import("days/day03.zig");
const day04 = @import("days/day04.zig");
const day05 = @import("days/day05.zig");
const day06 = @import("days/day06.zig");
const day07 = @import("days/day07.zig");
const day08 = @import("days/day08.zig");
const day09 = @import("days/day09.zig");
const day10 = @import("days/day10.zig");
const day11 = @import("days/day11.zig");
const day12 = @import("days/day12.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args_it = std.process.args();
    _ = args_it.next();

    const day_str = args_it.next() orelse {
        std.debug.print("Usage: aoc2025 <day>\n", .{});
        return;
    };

    const day = try std.fmt.parseInt(u8, day_str, 10);

    try runDay(allocator, day);
}

fn runDay(allocator: std.mem.Allocator, day: u8) !void {
    return switch (day) {
        1 => day01.solve(allocator),
        2 => day02.solve(allocator),
        3 => day03.solve(allocator),
        4 => day04.solve(allocator),
        5 => day05.solve(allocator),
        6 => day06.solve(allocator),
        7 => day07.solve(allocator),
        8 => day08.solve(allocator),
        9 => day09.solve(allocator),
        10 => day10.solve(allocator),
        11 => day11.solve(allocator),
        12 => day12.solve(allocator),
        else => error.UnknownDay,
    };
}
