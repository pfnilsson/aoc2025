const std = @import("std");
const helpers = @import("helpers");

const Box = struct { x: i64, y: i64, z: i64 };
const Connection = struct { box1: usize, box2: usize, distance: f64 };

const UnionFind = struct {
    parent: []usize,

    fn init(allocator: std.mem.Allocator, n: usize) !UnionFind {
        const parent = try allocator.alloc(usize, n);
        for (parent, 0..) |*p, i| {
            p.* = i;
        }
        return .{ .parent = parent };
    }

    fn deinit(self: *UnionFind, allocator: std.mem.Allocator) void {
        allocator.free(self.parent);
    }

    fn find(self: *UnionFind, x: usize) usize {
        if (self.parent[x] != x) {
            self.parent[x] = self.find(self.parent[x]);
        }
        return self.parent[x];
    }

    fn unite(self: *UnionFind, x: usize, y: usize) bool {
        const parent_x = self.find(x);
        const parent_y = self.find(y);
        if (parent_x != parent_y) {
            self.parent[parent_x] = parent_y;
            return true;
        }
        return false;
    }

    fn connected(self: *UnionFind, x: usize, y: usize) bool {
        return self.find(x) == self.find(y);
    }
};

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day08.txt");
    defer allocator.free(input);

    const boxes = try parse(allocator, input);
    defer allocator.free(boxes);

    const connections = try getConnections(allocator, boxes);
    defer allocator.free(connections);

    sortConnections(connections);

    const part1 = try solvePart1(allocator, boxes.len, connections);
    const part2 = try solvePart2(allocator, boxes, connections);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn solvePart1(allocator: std.mem.Allocator, num_boxes: usize, connections: []const Connection) !usize {
    var uf = try UnionFind.init(allocator, num_boxes);
    defer uf.deinit(allocator);

    for (connections[0..1000]) |conn| {
        _ = uf.unite(conn.box1, conn.box2);
    }

    const sizes = try getCircuitSizes(allocator, &uf);
    defer allocator.free(sizes);

    return sizes[0] * sizes[1] * sizes[2];
}

fn solvePart2(allocator: std.mem.Allocator, boxes: []const Box, connections: []const Connection) !i64 {
    var uf = try UnionFind.init(allocator, boxes.len);
    defer uf.deinit(allocator);

    var num_components = boxes.len;
    for (connections) |conn| {
        if (uf.unite(conn.box1, conn.box2)) {
            num_components -= 1;
            if (num_components == 1) {
                return boxes[conn.box1].x * boxes[conn.box2].x;
            }
        }
    }

    unreachable;
}

fn getCircuitSizes(allocator: std.mem.Allocator, uf: *UnionFind) ![]usize {
    const counts = try allocator.alloc(usize, uf.parent.len);
    @memset(counts, 0);

    for (0..uf.parent.len) |i| {
        _ = uf.find(i);
    }

    for (uf.parent) |root| {
        counts[root] += 1;
    }

    std.mem.sort(usize, counts, {}, std.sort.desc(usize));

    return counts;
}

fn parse(allocator: std.mem.Allocator, input: []const u8) ![]Box {
    var boxes = std.ArrayList(Box){};
    errdefer boxes.deinit(allocator);

    var lines = helpers.splitLines(input);
    while (lines.next()) |line| {
        var parts = helpers.splitCommas(line);
        const x = try std.fmt.parseInt(i64, parts.next() orelse continue, 10);
        const y = try std.fmt.parseInt(i64, parts.next() orelse return error.InvalidInput, 10);
        const z = try std.fmt.parseInt(i64, parts.next() orelse return error.InvalidInput, 10);
        try boxes.append(allocator, .{ .x = x, .y = y, .z = z });
    }

    return try boxes.toOwnedSlice(allocator);
}

fn getConnections(allocator: std.mem.Allocator, boxes: []const Box) ![]Connection {
    var connections = std.ArrayList(Connection){};
    errdefer connections.deinit(allocator);

    for (boxes, 0..) |box1, i| {
        for (boxes[i + 1 ..], i + 1..) |box2, j| {
            const dist = distance(box1, box2);
            try connections.append(allocator, .{ .box1 = i, .box2 = j, .distance = dist });
        }
    }

    return try connections.toOwnedSlice(allocator);
}

fn sortConnections(connections: []Connection) void {
    std.mem.sort(Connection, connections, {}, struct {
        fn lessThan(_: void, a: Connection, b: Connection) bool {
            return a.distance < b.distance;
        }
    }.lessThan);
}

fn distance(box1: Box, box2: Box) f64 {
    const dx: f64 = @floatFromInt(box1.x - box2.x);
    const dy: f64 = @floatFromInt(box1.y - box2.y);
    const dz: f64 = @floatFromInt(box1.z - box2.z);
    return @sqrt(dx * dx + dy * dy + dz * dz);
}
