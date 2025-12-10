const std = @import("std");
const helpers = @import("helpers");

const Point = struct { x: i64, y: i64 };
const Problem = struct { operator: u8, operands: []u64 };

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day07.txt");
    defer allocator.free(input);

    const grid = try helpers.Grid.parse(allocator, input);
    defer grid.deinit();

    const start = findStart(grid);

    const part1 = try solvePart1(allocator, grid, start);
    const part2 = try solvePart2(allocator, grid, start);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn solvePart1(allocator: std.mem.Allocator, grid: helpers.Grid, start: Point) !u64 {
    var queue = std.ArrayList(Point){};
    defer queue.deinit(allocator);

    var visited = std.AutoHashMap(Point, void).init(allocator);
    defer visited.deinit();

    try queue.append(allocator, start);

    var splits: u64 = 0;
    while (queue.pop()) |pos| {
        if (walkUntilSplitter(grid, pos)) |splitter| {
            if (!visited.contains(splitter)) {
                try visited.put(splitter, {});
                splits += 1;
                try queueSplitPaths(allocator, grid, splitter, &queue);
            }
        }
    }

    return splits;
}

fn solvePart2(allocator: std.mem.Allocator, grid: helpers.Grid, start: Point) !u64 {
    var cache = std.AutoHashMap(Point, u64).init(allocator);
    defer cache.deinit();

    return try countPaths(allocator, grid, start, &cache);
}

fn countPaths(
    allocator: std.mem.Allocator,
    grid: helpers.Grid,
    start_pos: Point,
    cache: *std.AutoHashMap(Point, u64),
) !u64 {
    if (cache.get(start_pos)) |cached| {
        return cached;
    }

    const splitter = walkUntilSplitter(grid, start_pos);
    if (splitter == null) {
        try cache.put(start_pos, 1);
        return 1;
    }

    var paths: u64 = 0;
    if (grid.west(splitter.?.x, splitter.?.y)) |left| {
        paths += try countPaths(allocator, grid, .{ .x = left.x, .y = left.y }, cache);
    }
    if (grid.east(splitter.?.x, splitter.?.y)) |right| {
        paths += try countPaths(allocator, grid, .{ .x = right.x, .y = right.y }, cache);
    }

    try cache.put(start_pos, paths);
    return paths;
}

fn walkUntilSplitter(grid: helpers.Grid, start_pos: Point) ?Point {
    var curr = start_pos;
    while (true) {
        const next = grid.south(curr.x, curr.y);
        if (next) |cell| {
            if (cell.val == '^') {
                return .{ .x = cell.x, .y = cell.y };
            }
            curr = .{ .x = cell.x, .y = cell.y };
        } else {
            return null;
        }
    }
}

fn queueSplitPaths(
    allocator: std.mem.Allocator,
    grid: helpers.Grid,
    splitter: Point,
    queue: *std.ArrayList(Point),
) !void {
    if (grid.west(splitter.x, splitter.y)) |left| {
        try queue.append(allocator, .{ .x = left.x, .y = left.y });
    }
    if (grid.east(splitter.x, splitter.y)) |right| {
        try queue.append(allocator, .{ .x = right.x, .y = right.y });
    }
}

fn findStart(grid: helpers.Grid) Point {
    var it = grid.iterate();
    while (it.next()) |cell| {
        if (cell.val == 'S') {
            return .{ .x = cell.x, .y = cell.y };
        }
    }
    unreachable;
}
