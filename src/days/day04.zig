const std = @import("std");
const helpers = @import("helpers");

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day04.txt");
    defer allocator.free(input);

    var grid = try helpers.Grid.parse(allocator, input);
    defer grid.deinit();

    const part1 = solvePart1(grid);
    const part2 = solvePart2(grid);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn solvePart1(grid: helpers.Grid) u64 {
    var total: u64 = 0;
    var it = grid.iterate();
    while (it.next()) |cell| {
        if (cell.val == '@') {
            var neighbor_rolls: u8 = 0;
            for (grid.neighbors(cell.x, cell.y)) |maybe_neighbor| {
                if (maybe_neighbor) |neighbor| {
                    if (neighbor.val == '@') {
                        neighbor_rolls += 1;
                    }
                }
            }

            if (neighbor_rolls < 4) {
                total += 1;
            }
        }
    }
    return total;
}

fn solvePart2(grid: helpers.Grid) u64 {
    var total: u64 = 0;

    var run_again = true;
    while (run_again) {
        var it = grid.iterate();
        run_again = false;
        while (it.next()) |cell| {
            if (cell.val == '@') {
                var neighbor_rolls: u8 = 0;
                for (grid.neighbors(cell.x, cell.y)) |maybe_neighbor| {
                    if (maybe_neighbor) |neighbor| {
                        if (neighbor.val == '@') {
                            neighbor_rolls += 1;
                        }
                    }
                }

                if (neighbor_rolls < 4) {
                    grid.set(cell.x, cell.y, '.');
                    total += 1;
                    run_again = true;
                }
            }
        }
    }
    return total;
}
