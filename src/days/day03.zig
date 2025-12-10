const std = @import("std");
const helpers = @import("helpers");

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day03.txt");
    defer allocator.free(input);

    const part1 = solvePart1(input);
    const part2 = solvePart2(input);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn solvePart1(input: []const u8) u64 {
    var banks = helpers.splitLines(input);
    var total: u64 = 0;

    while (banks.next()) |bank| {
        var max_first: u64 = 1;
        var min_second: u64 = 1;

        for (bank, 1..) |battery, i| {
            const bank_width = bank.len;
            const joltage: u64 = battery - '0';

            if (joltage > max_first and i != bank_width) {
                max_first = joltage;
                min_second = 1;
                continue;
            }

            if (joltage > min_second) {
                min_second = joltage;
            }
        }

        total += 10 * max_first + min_second;
    }

    return total;
}

fn solvePart2(input: []const u8) u64 {
    var banks = helpers.splitLines(input);
    var total: u64 = 0;

    while (banks.next()) |bank| {
        var digits: [12]u8 = .{1} ** 12;
        const bank_width = bank.len;

        for (bank, 0..) |battery, i| {
            const joltage: u8 = battery - '0';
            const remaining = bank_width - i;

            for (0..12) |j| {
                if (remaining < 12 - j) {
                    continue;
                }

                if (joltage > digits[j]) {
                    digits[j] = joltage;

                    for (j + 1..12) |k| {
                        digits[k] = 1;
                    }
                    break;
                }
            }
        }

        var num: u64 = 0;
        for (digits) |digit| {
            num = num * 10 + digit;
        }
        total += num;
    }

    return total;
}
