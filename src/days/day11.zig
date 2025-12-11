const std = @import("std");
const helpers = @import("helpers");

const Graph = std.StringHashMap([][]const u8);

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day11.txt");
    defer allocator.free(input);

    var graph = try parse(allocator, input);
    defer {
        var iter = graph.valueIterator();
        while (iter.next()) |connections| {
            allocator.free(connections.*);
        }
        graph.deinit();
    }

    const part1: u64 = try solvePart1(allocator, graph);
    const part2: u64 = try solvePart2(allocator, graph);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn parse(allocator: std.mem.Allocator, input: []const u8) !Graph {
    var graph = Graph.init(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var parts = std.mem.splitSequence(u8, line, ": ");
        const node = parts.next() orelse continue;

        const connections_str = parts.next() orelse continue;
        var connections = std.ArrayList([]const u8){};

        var conn_iter = std.mem.splitScalar(u8, connections_str, ' ');
        while (conn_iter.next()) |conn| {
            if (conn.len > 0) try connections.append(allocator, conn);
        }

        try graph.put(node, try connections.toOwnedSlice(allocator));
    }

    return graph;
}

fn solvePart1(allocator: std.mem.Allocator, graph: Graph) !u64 {
    const start = "you";
    const goal = "out";

    var cache = std.StringHashMap(u64).init(allocator);
    defer cache.deinit();

    return try countPaths(graph, start, goal, &cache);
}

fn solvePart2(allocator: std.mem.Allocator, graph: Graph) !u64 {
    const routes = [_][4][]const u8{
        .{ "svr", "fft", "dac", "out" },
        .{ "svr", "dac", "fft", "out" },
    };

    var cache = std.StringHashMap(u64).init(allocator);
    defer cache.deinit();

    for (routes) |route| {
        var total: u64 = 1;
        for (0..route.len - 1) |i| {
            cache.clearRetainingCapacity();
            const paths = try countPaths(graph, route[i], route[i + 1], &cache);
            total *= paths;
        }

        if (total > 0) {
            return total;
        }
    }

    return 0;
}

fn countPaths(graph: Graph, node: []const u8, goal: []const u8, cache: *std.StringHashMap(u64)) !u64 {
    if (std.mem.eql(u8, node, goal)) {
        return 1;
    }

    if (cache.get(node)) |cached| {
        return cached;
    }

    const neighbors = graph.get(node) orelse {
        return 0;
    };

    var total: u64 = 0;
    for (neighbors) |neighbor| {
        total += try countPaths(graph, neighbor, goal, cache);
    }

    try cache.put(node, total);
    return total;
}
