const std = @import("std");
const helpers = @import("helpers");

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day01.txt");
    defer allocator.free(input);

    const turns = try parse(allocator, input);
    defer allocator.free(turns);

    const part1: i64 = solvePart1(turns);
    const part2: i64 = solvePart2(turns);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn parse(allocator: std.mem.Allocator, input: []const u8) ![]i64 {
    var list = std.ArrayList(i64){};
    defer list.deinit(allocator);

    var it = helpers.splitLines(input);
    while (it.next()) |line| {
        const sign = line[0];
        const num_str = line[1..];
        const val = try std.fmt.parseInt(i64, num_str, 10);

        const signed_val = if (sign == 'R') val else -val;
        try list.append(allocator, signed_val);
    }

    return try list.toOwnedSlice(allocator);
}

fn solvePart1(turns: []i64) i64 {
    var curr: i64 = 50;
    var clicks: i64 = 0;
    for (turns) |turn| {
        curr += turn;
        curr = @mod(curr, 100);

        if (curr == 0) {
            clicks += 1;
        }
    }

    return clicks;
}

fn solvePart2(turns: []i64) i64 {
    var curr: i64 = 50;
    var clicks: i64 = 0;
    for (turns) |turn| {
        const old = curr;
        curr += turn;

        if (turn > 0) {
            clicks += @divFloor(curr, 100);
        } else if (turn < 0) {
            clicks += @divFloor(old - 1, 100) - @divFloor(curr - 1, 100);
        }

        curr = @mod(curr, 100);
    }

    return clicks;
}
