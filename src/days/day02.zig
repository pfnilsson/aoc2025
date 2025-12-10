const std = @import("std");
const helpers = @import("helpers");

const Range = struct { start: u64, end: u64 };

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day02.txt");
    defer allocator.free(input);

    const ranges = try parse(allocator, input);
    defer allocator.free(ranges);

    var max_val: u64 = 0;
    for (ranges) |range| {
        if (range.end > max_val) max_val = range.end;
    }

    const invalid_ids = try generateInvalidIDs(allocator, max_val);
    defer allocator.free(invalid_ids);

    const part1 = solvePart1(ranges, invalid_ids);
    const part2 = solvePart2(ranges, invalid_ids);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn solvePart1(ranges: []Range, invalid_ids: []u64) u64 {
    var total: u64 = 0;
    for (ranges) |range| {
        for (invalid_ids) |num| {
            if (num >= range.start and num <= range.end) {
                const len = digitCount(num);
                if (len % 2 == 0) {
                    const divisor = std.math.pow(u64, 10, len / 2);
                    if (num / divisor == num % divisor) {
                        total += num;
                    }
                }
            }
        }
    }
    return total;
}

fn solvePart2(ranges: []Range, invalid_ids: []u64) u64 {
    var total: u64 = 0;
    for (ranges) |range| {
        for (invalid_ids) |num| {
            if (num >= range.start and num <= range.end) {
                total += num;
            }
        }
    }
    return total;
}

fn generateInvalidIDs(allocator: std.mem.Allocator, max_val: u64) ![]u64 {
    var seen = std.AutoHashMap(u64, void).init(allocator);
    defer seen.deinit();

    const max_digits = digitCount(max_val);

    for (1..max_digits / 2 + 1) |chunk_size| {
        const min_chunk: u64 = if (chunk_size == 1) 1 else std.math.pow(u64, 10, chunk_size - 1);
        const max_chunk: u64 = std.math.pow(u64, 10, chunk_size) - 1;

        for (min_chunk..max_chunk + 1) |chunk| {
            var num: u64 = chunk;
            for (0..19) |_| {
                const multiplier = std.math.pow(u64, 10, chunk_size);
                const new_num = @mulWithOverflow(num, multiplier);
                if (new_num[1] != 0) {
                    break;
                }

                num = new_num[0] +| chunk;
                if (num > max_val) {
                    break;
                }

                try seen.put(num, {});
            }
        }
    }

    var list = std.ArrayList(u64){};
    defer list.deinit(allocator);

    var it = seen.keyIterator();
    while (it.next()) |key| {
        try list.append(allocator, key.*);
    }

    return try list.toOwnedSlice(allocator);
}

fn parse(allocator: std.mem.Allocator, input: []const u8) ![]Range {
    var list = std.ArrayList(Range){};
    defer list.deinit(allocator);

    var it = helpers.splitCommas(input);
    while (it.next()) |range_str| {
        const range = try parseRange(range_str);
        try list.append(allocator, range);
    }

    return try list.toOwnedSlice(allocator);
}

fn parseRange(range_str: []const u8) !Range {
    var split_range = helpers.split(range_str, '-');
    const first = split_range.next() orelse return error.MissingStart;
    const second = split_range.next() orelse return error.MissingEnd;

    const start = std.fmt.parseInt(u64, first, 10) catch return error.InvalidNumber;
    const end = std.fmt.parseInt(u64, second, 10) catch return error.InvalidNumber;

    return .{ .start = start, .end = end };
}

fn digitCount(n: u64) u8 {
    if (n == 0) return 1;
    return @intCast(std.math.log10(n) + 1);
}
