const std = @import("std");
const helpers = @import("helpers");

const Range = struct { start: u64, end: u64 };

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day05.txt");
    defer allocator.free(input);

    const parsed_input = try parse(allocator, input);
    defer allocator.free(parsed_input.ranges);
    defer allocator.free(parsed_input.ingredients);

    const part1 = solvePart1(parsed_input.ranges, parsed_input.ingredients);
    const part2 = try solvePart2(allocator, parsed_input.ranges);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn parse(allocator: std.mem.Allocator, input: []const u8) !struct { ranges: []Range, ingredients: []u64 } {
    const separator_idx = std.mem.indexOf(u8, input, "\n\n") orelse return error.NoSeparator;
    const first = input[0..separator_idx];
    const second = input[separator_idx + 2 ..];

    var ranges = std.ArrayList(Range){};
    errdefer ranges.deinit(allocator);

    var lines = helpers.splitLines(first);
    while (lines.next()) |line| {
        var parts = helpers.split(line, '-');
        const start_str = parts.next() orelse return error.Missing;
        const end_str = parts.next() orelse return error.Missing;
        const start = try std.fmt.parseInt(u64, start_str, 10);
        const end = try std.fmt.parseInt(u64, end_str, 10);
        try ranges.append(allocator, .{ .start = start, .end = end });
    }

    const owned_ranges = try ranges.toOwnedSlice(allocator);
    errdefer allocator.free(owned_ranges);

    var ingredients = std.ArrayList(u64){};
    errdefer ingredients.deinit(allocator);

    var ingredient_lines = helpers.splitLines(second);
    while (ingredient_lines.next()) |line| {
        const num = try std.fmt.parseInt(u64, line, 10);
        try ingredients.append(allocator, num);
    }

    return .{
        .ranges = owned_ranges,
        .ingredients = try ingredients.toOwnedSlice(allocator),
    };
}

fn sortRanges(ranges: []Range) void {
    std.mem.sort(Range, ranges, {}, struct {
        pub fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);
}

fn solvePart1(ranges: []Range, ingredients: []u64) u64 {
    var total: u64 = 0;
    for (ingredients) |ingredient| {
        for (ranges) |range| {
            if (ingredient >= range.start and ingredient <= range.end) {
                total += 1;
                break;
            }
        }
    }

    return total;
}

fn solvePart2(allocator: std.mem.Allocator, ranges: []Range) !u64 {
    sortRanges(ranges);

    var merged = try std.ArrayList(Range).initCapacity(allocator, ranges.len);
    defer merged.deinit(allocator);

    merged.appendAssumeCapacity(ranges[0]);

    for (ranges[1..]) |range| {
        const last = &merged.items[merged.items.len - 1];
        if (range.start <= last.end + 1) {
            last.end = @max(last.end, range.end);
        } else {
            try merged.append(allocator, range);
        }
    }

    var count: u64 = 0;
    for (merged.items) |range| {
        count += range.end - range.start + 1;
    }

    return count;
}
