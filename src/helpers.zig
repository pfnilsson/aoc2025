const std = @import("std");

pub fn readInputFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

pub fn split(input: []const u8, delimiter: u8) std.mem.TokenIterator(u8, .scalar) {
    return std.mem.tokenizeScalar(u8, input, delimiter);
}

pub fn splitLines(input: []const u8) std.mem.TokenIterator(u8, .scalar) {
    return split(input, '\n');
}

pub fn splitCommas(input: []const u8) std.mem.TokenIterator(u8, .any) {
    return std.mem.tokenizeAny(u8, input, ",\n");
}

pub const Grid = struct {
    data: [][]u8,
    width: i64,
    height: i64,
    allocator: std.mem.Allocator,

    pub const Cell = struct { x: i64, y: i64, val: u8 };

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Grid {
        var rows = std.ArrayList([]u8){};
        errdefer {
            for (rows.items) |row| {
                allocator.free(row);
            }
            rows.deinit(allocator);
        }

        var lines = splitLines(input);
        while (lines.next()) |line| {
            const row = try allocator.dupe(u8, line);
            try rows.append(allocator, row);
        }

        const data = try rows.toOwnedSlice(allocator);
        return Grid{
            .data = data,
            .width = if (data.len > 0) @intCast(data[0].len) else 0,
            .height = @intCast(data.len),
            .allocator = allocator,
        };
    }

    pub fn get(self: Grid, x: i64, y: i64) ?Cell {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) {
            return null;
        }
        return Cell{ .x = x, .y = y, .val = self.data[@intCast(y)][@intCast(x)] };
    }

    pub fn set(self: Grid, x: i64, y: i64, value: u8) void {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return;
        self.data[@intCast(y)][@intCast(x)] = value;
    }

    pub fn deinit(self: Grid) void {
        for (self.data) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.data);
    }

    pub fn print(self: Grid) void {
        for (self.data) |row| {
            std.debug.print("{s}\n", .{row});
        }
    }

    pub fn neighbors(self: Grid, x: i64, y: i64) [8]?Cell {
        return .{
            self.northWest(x, y),
            self.north(x, y),
            self.northEast(x, y),
            self.west(x, y),
            self.east(x, y),
            self.southWest(x, y),
            self.south(x, y),
            self.southEast(x, y),
        };
    }

    pub fn cardinals(self: Grid, x: i64, y: i64) [4]?Cell {
        return .{
            self.north(x, y),
            self.west(x, y),
            self.east(x, y),
            self.south(x, y),
        };
    }

    pub fn north(self: Grid, x: i64, y: i64) ?Cell {
        return self.get(x, y - 1);
    }

    pub fn south(self: Grid, x: i64, y: i64) ?Cell {
        return self.get(x, y + 1);
    }

    pub fn west(self: Grid, x: i64, y: i64) ?Cell {
        return self.get(x - 1, y);
    }

    pub fn east(self: Grid, x: i64, y: i64) ?Cell {
        return self.get(x + 1, y);
    }

    pub fn northWest(self: Grid, x: i64, y: i64) ?Cell {
        return self.get(x - 1, y - 1);
    }

    pub fn northEast(self: Grid, x: i64, y: i64) ?Cell {
        return self.get(x + 1, y - 1);
    }

    pub fn southWest(self: Grid, x: i64, y: i64) ?Cell {
        return self.get(x - 1, y + 1);
    }

    pub fn southEast(self: Grid, x: i64, y: i64) ?Cell {
        return self.get(x + 1, y + 1);
    }

    pub fn iterate(self: Grid) Iterator {
        return Iterator{ .grid = self, .x = 0, .y = 0 };
    }

    pub const Iterator = struct {
        grid: Grid,
        x: i64,
        y: i64,

        pub fn next(self: *Iterator) ?Cell {
            if (self.y >= self.grid.height) {
                return null;
            }

            const result = Cell{
                .x = self.x,
                .y = self.y,
                .val = self.grid.data[@intCast(self.y)][@intCast(self.x)],
            };

            self.x += 1;
            if (self.x >= self.grid.width) {
                self.x = 0;
                self.y += 1;
            }

            return result;
        }
    };
};
