const std = @import("std");
const helpers = @import("helpers");

const Present = [3][3]u8;
const Region = struct {
    width: u8,
    height: u8,
    present_counts: []u8,
};

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day12.txt");
    defer allocator.free(input);

    const parsed = try parse(allocator, input);
    defer allocator.free(parsed.presents);
    defer {
        for (parsed.regions) |region| allocator.free(region.present_counts);
        allocator.free(parsed.regions);
    }

    var total: u16 = 0;
    for (parsed.regions) |region| {
        const raw_fit: u16 = @as(u16, region.width / 3) * (region.height / 3);
        var required: u16 = 0;
        for (region.present_counts) |c| {
            required += c;
        }

        // :(
        if (raw_fit >= required) {
            total += 1;
        }
    }

    const part1: u64 = total;

    std.debug.print("Part 1: {d}\n", .{part1});
}

fn parse(allocator: std.mem.Allocator, input: []const u8) !struct { presents: []Present, regions: []Region } {
    var presents = std.ArrayList(Present){};
    var regions = std.ArrayList(Region){};

    var sections = std.mem.splitSequence(u8, input, "\n\n");

    while (sections.next()) |section| {
        if (section.len == 0) continue;

        if (isPresent(section)) {
            try presents.append(allocator, parsePresent(section));
        } else {
            var lines = std.mem.splitScalar(u8, section, '\n');
            while (lines.next()) |line| {
                if (line.len == 0) continue;
                try regions.append(allocator, try parseRegion(allocator, line));
            }
        }
    }

    return .{
        .presents = try presents.toOwnedSlice(allocator),
        .regions = try regions.toOwnedSlice(allocator),
    };
}

fn isPresent(section: []const u8) bool {
    return section.len >= 2 and section[0] >= '0' and section[0] <= '9' and section[1] == ':';
}

fn parsePresent(section: []const u8) Present {
    var lines = std.mem.splitScalar(u8, section, '\n');
    _ = lines.next();

    var present: Present = undefined;
    for (0..3) |row| {
        present[row] = lines.next().?[0..3].*;
    }
    return present;
}

fn parseRegion(allocator: std.mem.Allocator, line: []const u8) !Region {
    const x_pos = std.mem.indexOf(u8, line, "x") orelse return error.InvalidFormat;
    const colon_pos = std.mem.indexOf(u8, line, ":") orelse return error.InvalidFormat;

    const width = try std.fmt.parseInt(u8, line[0..x_pos], 10);
    const height = try std.fmt.parseInt(u8, line[x_pos + 1 .. colon_pos], 10);

    var counts = std.ArrayList(u8){};
    var nums = std.mem.tokenizeScalar(u8, line[colon_pos + 1 ..], ' ');
    while (nums.next()) |num| {
        const count = try std.fmt.parseInt(u8, num, 10);
        try counts.append(allocator, count);
    }

    return .{
        .width = width,
        .height = height,
        .present_counts = try counts.toOwnedSlice(allocator),
    };
}
