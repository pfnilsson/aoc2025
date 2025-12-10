const std = @import("std");
const helpers = @import("helpers");

const Tile = struct { x: i64, y: i64 };

const Edge = struct {
    min_x: i64,
    max_x: i64,
    min_y: i64,
    max_y: i64,
};

const Rectangle = struct {
    tile1: Tile,
    tile2: Tile,

    fn area(self: Rectangle) u64 {
        const width = @abs(self.tile1.x - self.tile2.x) + 1;
        const height = @abs(self.tile1.y - self.tile2.y) + 1;
        return width * height;
    }
};

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day09.txt");
    defer allocator.free(input);

    const tiles = try parse(allocator, input);
    defer allocator.free(tiles);

    const rectangles = try orderedRectangles(allocator, tiles);
    defer allocator.free(rectangles);

    const part1 = solvePart1(rectangles);
    const part2 = try solvePart2(allocator, tiles, rectangles);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn parse(allocator: std.mem.Allocator, input: []const u8) ![]Tile {
    var lines = helpers.splitLines(input);
    var tiles = std.ArrayList(Tile){};
    errdefer tiles.deinit(allocator);

    while (lines.next()) |line| {
        var parts = std.mem.splitScalar(u8, line, ',');
        const x = try std.fmt.parseInt(i64, parts.next().?, 10);
        const y = try std.fmt.parseInt(i64, parts.next().?, 10);
        try tiles.append(allocator, .{ .x = x, .y = y });
    }
    return tiles.toOwnedSlice(allocator);
}

fn solvePart1(rectangles: []Rectangle) u64 {
    return rectangles[0].area();
}

fn solvePart2(allocator: std.mem.Allocator, tiles: []Tile, rectangles: []Rectangle) !u64 {
    const edges = try buildEdges(allocator, tiles);
    defer allocator.free(edges);

    for (rectangles) |rectangle| {
        if (isFullyContained(edges, rectangle)) {
            return rectangle.area();
        }
    }

    unreachable;
}

fn buildEdges(allocator: std.mem.Allocator, tiles: []Tile) ![]Edge {
    const edges = try allocator.alloc(Edge, tiles.len);
    for (0..tiles.len) |i| {
        const curr = tiles[i];
        const next = tiles[(i + 1) % tiles.len];
        edges[i] = .{
            .min_x = @min(curr.x, next.x),
            .max_x = @max(curr.x, next.x),
            .min_y = @min(curr.y, next.y),
            .max_y = @max(curr.y, next.y),
        };
    }
    return edges;
}

fn isFullyContained(edges: []Edge, rect: Rectangle) bool {
    const min_x = @min(rect.tile1.x, rect.tile2.x);
    const max_x = @max(rect.tile1.x, rect.tile2.x);
    const min_y = @min(rect.tile1.y, rect.tile2.y);
    const max_y = @max(rect.tile1.y, rect.tile2.y);

    for (edges) |edge| {
        if (min_x < edge.max_x and max_x > edge.min_x and
            min_y < edge.max_y and max_y > edge.min_y)
        {
            return false;
        }
    }
    return true;
}

fn orderedRectangles(allocator: std.mem.Allocator, tiles: []Tile) ![]Rectangle {
    var rectangles = std.ArrayList(Rectangle){};
    defer rectangles.deinit(allocator);

    for (tiles, 0..) |tile1, i| {
        for (tiles[i + 1 ..]) |tile2| {
            try rectangles.append(allocator, .{ .tile1 = tile1, .tile2 = tile2 });
        }
    }

    std.mem.sort(Rectangle, rectangles.items, {}, struct {
        fn lessThan(_: void, a: Rectangle, b: Rectangle) bool {
            return a.area() > b.area();
        }
    }.lessThan);

    return rectangles.toOwnedSlice(allocator);
}
