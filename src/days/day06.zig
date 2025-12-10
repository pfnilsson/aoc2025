const std = @import("std");
const helpers = @import("helpers");

const Problem = struct { operator: u8, operands: []u64 };

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day06.txt");
    defer allocator.free(input);

    const problems = try parsePart1(allocator, input);
    defer {
        for (problems) |p| {
            allocator.free(p.operands);
        }
        allocator.free(problems);
    }

    const part1 = solveProblems(problems);

    const problems2 = try parsePart2(allocator, input);
    defer {
        for (problems2) |p| {
            allocator.free(p.operands);
        }
        allocator.free(problems2);
    }

    const part2 = solveProblems(problems2);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn solveProblems(problems: []Problem) u64 {
    var total: u64 = 0;
    for (problems) |problem| {
        const result = switch (problem.operator) {
            '+' => doAdd(problem.operands),
            '*' => doMultiply(problem.operands),
            else => unreachable,
        };
        total += result;
    }
    return total;
}

fn parsePart1(allocator: std.mem.Allocator, input: []const u8) ![]Problem {
    var lines_list = std.ArrayList([]const u8){};
    defer lines_list.deinit(allocator);

    var line_iter = helpers.splitLines(input);
    while (line_iter.next()) |line| {
        if (line.len > 0) try lines_list.append(allocator, line);
    }
    const lines = lines_list.items;

    var max_len: usize = 0;
    for (lines) |line| {
        max_len = @max(max_len, line.len);
    }

    var block_starts = std.ArrayList(usize){};
    defer block_starts.deinit(allocator);

    var block_ends = std.ArrayList(usize){};
    defer block_ends.deinit(allocator);

    var in_block = false;
    for (0..max_len) |col| {
        const all_whitespace = for (lines) |line| {
            if (col < line.len and line[col] != ' ') break false;
        } else true;

        if (!all_whitespace and !in_block) {
            try block_starts.append(allocator, col);
            in_block = true;
        } else if (all_whitespace and in_block) {
            try block_ends.append(allocator, col);
            in_block = false;
        }
    }
    if (in_block) try block_ends.append(allocator, max_len);

    var problems = std.ArrayList(Problem){};
    errdefer problems.deinit(allocator);

    for (block_starts.items, block_ends.items) |start, end| {
        var operands = std.ArrayList(u64){};
        errdefer operands.deinit(allocator);

        for (lines[0 .. lines.len - 1]) |line| {
            const slice = if (end <= line.len) line[start..end] else line[start..];
            const trimmed = std.mem.trim(u8, slice, " ");
            const num = try std.fmt.parseInt(u64, trimmed, 10);
            try operands.append(allocator, num);
        }

        const last_line = lines[lines.len - 1];
        const op_slice = if (end <= last_line.len) last_line[start..end] else last_line[start..];
        const operator = std.mem.trim(u8, op_slice, " ")[0];

        try problems.append(allocator, .{
            .operator = operator,
            .operands = try operands.toOwnedSlice(allocator),
        });
    }

    return try problems.toOwnedSlice(allocator);
}

fn parsePart2(allocator: std.mem.Allocator, input: []const u8) ![]Problem {
    var lines_list = std.ArrayList([]const u8){};
    defer lines_list.deinit(allocator);

    var line_iter = helpers.splitLines(input);
    while (line_iter.next()) |line| {
        if (line.len > 0) try lines_list.append(allocator, line);
    }
    const lines = lines_list.items;

    var max_len: usize = 0;
    for (lines) |line| {
        max_len = @max(max_len, line.len);
    }

    var block_starts = std.ArrayList(usize){};
    defer block_starts.deinit(allocator);

    var block_ends = std.ArrayList(usize){};
    defer block_ends.deinit(allocator);

    var in_block = false;
    for (0..max_len) |col| {
        const all_whitespace = for (lines) |line| {
            if (col < line.len and line[col] != ' ') break false;
        } else true;

        if (!all_whitespace and !in_block) {
            try block_starts.append(allocator, col);
            in_block = true;
        } else if (all_whitespace and in_block) {
            try block_ends.append(allocator, col);
            in_block = false;
        }
    }

    if (in_block) {
        try block_ends.append(allocator, max_len);
    }

    var problems = std.ArrayList(Problem){};
    errdefer problems.deinit(allocator);

    for (block_starts.items, block_ends.items) |start, end| {
        var operands = std.ArrayList(u64){};
        errdefer operands.deinit(allocator);

        for (start..end) |col| {
            var operand: u64 = 0;
            var has_digit = false;

            for (lines[0 .. lines.len - 1]) |line| {
                if (col < line.len) {
                    const ch = line[col];
                    if (ch >= '0' and ch <= '9') {
                        operand = operand * 10 + (ch - '0');
                        has_digit = true;
                    }
                }
            }

            if (has_digit) {
                try operands.append(allocator, operand);
            }
        }

        const last_line = lines[lines.len - 1];
        const op_slice = if (end <= last_line.len) last_line[start..end] else last_line[start..];
        const operator = std.mem.trim(u8, op_slice, " ")[0];

        try problems.append(allocator, .{
            .operator = operator,
            .operands = try operands.toOwnedSlice(allocator),
        });
    }

    return try problems.toOwnedSlice(allocator);
}

fn doAdd(operands: []u64) u64 {
    var result: u64 = 0;
    for (operands) |operand| {
        result += operand;
    }

    return result;
}

fn doMultiply(operands: []u64) u64 {
    var result: u64 = 1;
    for (operands) |operand| {
        result *= operand;
    }

    return result;
}
