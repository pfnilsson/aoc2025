const std = @import("std");
const helpers = @import("helpers");

const Machine = struct {
    const Mask = u16;
    const INF: i64 = std.math.maxInt(i64);

    lights: []bool,
    buttons: [][]u8,
    joltage: []u8,

    fn deinit(self: Machine, allocator: std.mem.Allocator) void {
        allocator.free(self.lights);
        for (self.buttons) |button| {
            allocator.free(button);
        }
        allocator.free(self.buttons);
        allocator.free(self.joltage);
    }

    fn solveLights(self: Machine) u64 {
        const target: Mask = self.buildTargetMask();
        const button_masks = self.buildButtonMasks();
        const num_combos: Mask = @as(Mask, 1) << @intCast(self.buttons.len);

        var best: u64 = std.math.maxInt(u64);
        var combo: Mask = 0;
        while (combo < num_combos) : (combo += 1) {
            var state: Mask = 0;

            var i: usize = 0;
            while (i < self.buttons.len) : (i += 1) {
                if (Machine.isButtonPressed(combo, i)) {
                    state ^= button_masks[i];
                }
            }

            if (state == target) {
                const presses = @as(u64, @popCount(combo));
                if (presses < best) {
                    best = presses;
                }
            }
        }

        return best;
    }

    fn solveJoltage(self: Machine, allocator: std.mem.Allocator) !u64 {
        const rows = self.joltage.len;
        const cols = self.buttons.len;

        var A = try allocator.alloc([]i64, rows);
        defer {
            for (A) |row_slice| {
                allocator.free(row_slice);
            }
            allocator.free(A);
        }

        var b = try allocator.alloc(i64, rows);
        defer allocator.free(b);

        var c = try allocator.alloc(i64, cols);
        defer allocator.free(c);

        var r: usize = 0;
        while (r < rows) : (r += 1) {
            A[r] = try allocator.alloc(i64, cols);
            var j: usize = 0;
            while (j < cols) : (j += 1) {
                A[r][j] = 0;
            }
            b[r] = @intCast(self.joltage[r]);
        }

        var j: usize = 0;
        while (j < cols) : (j += 1) {
            const affected = self.buttons[j];
            if (affected.len == 0) {
                c[j] = 0;
            } else {
                var min_rhs: i64 = std.math.maxInt(i64);
                for (affected) |idx_u8| {
                    const ci: usize = @intCast(idx_u8);
                    A[ci][j] = 1;
                    const rhs_val: i64 = @intCast(self.joltage[ci]);
                    if (rhs_val < min_rhs) {
                        min_rhs = rhs_val;
                    }
                }
                c[j] = min_rhs;
            }
        }

        const row_count: usize = rows;
        const rank = Machine.reduceToDiagnoalWithFreeCols(A, b, c, row_count, cols);

        r = 0;
        while (r < rows) : (r += 1) {
            var any_nonzero = false;
            var k: usize = 0;
            while (k < cols) : (k += 1) {
                if (A[r][k] != 0) {
                    any_nonzero = true;
                    break;
                }
            }
            if (!any_nonzero and b[r] != 0) {
                return error.NoSolution;
            }
        }

        const best = Machine.minPressesForSystem(A, b, c, rank, cols);
        return @intCast(best);
    }

    fn swapRow(A: [][]i64, b: []i64, i: usize, j: usize) void {
        if (i == j) {
            return;
        }
        const tmp_row = A[i];
        A[i] = A[j];
        A[j] = tmp_row;

        const tmp_b = b[i];
        b[i] = b[j];
        b[j] = tmp_b;
    }

    fn swapCol(A: [][]i64, c: []i64, i: usize, j: usize) void {
        if (i == j) {
            return;
        }
        const rows = A.len;

        var r: usize = 0;
        while (r < rows) : (r += 1) {
            const tmp = A[r][i];
            A[r][i] = A[r][j];
            A[r][j] = tmp;
        }

        const tmp_c = c[i];
        c[i] = c[j];
        c[j] = tmp_c;
    }

    fn reduceRow(A: [][]i64, b: []i64, pivot: usize, row: usize, cols: usize) void {
        const pivot_val = A[pivot][pivot];
        if (pivot_val == 0) {
            return;
        }

        const x: i64 = pivot_val;
        const y: i64 = -A[row][pivot];

        if (y == 0) {
            return;
        }

        const d: i64 = @intCast(std.math.gcd(@abs(x), @abs(y)));

        var k: usize = 0;
        while (k < cols) : (k += 1) {
            const num = y * A[pivot][k] + x * A[row][k];
            A[row][k] = @divTrunc(num, d);
        }
        const num_b = y * b[pivot] + x * b[row];
        b[row] = @divTrunc(num_b, d);
    }

    fn reduceToDiagnoalWithFreeCols(
        A: [][]i64,
        b: []i64,
        c: []i64,
        rows: usize,
        cols: usize,
    ) usize {
        var rank: usize = 0;
        var i: usize = 0;
        var col_idx: usize = 0;

        while (i < rows and col_idx < cols) : (col_idx += 1) {
            var found_col: ?usize = null;
            var k = col_idx;
            while (k < cols) : (k += 1) {
                var has_nonzero = false;
                var r: usize = i;
                while (r < rows) : (r += 1) {
                    if (A[r][k] != 0) {
                        has_nonzero = true;
                        break;
                    }
                }
                if (has_nonzero) {
                    found_col = k;
                    break;
                }
            }
            if (found_col == null) {
                break;
            }

            const pivot_col = found_col.?;
            Machine.swapCol(A, c, col_idx, pivot_col);

            var pivot_row = i;
            var r2: usize = i;
            while (r2 < rows) : (r2 += 1) {
                if (A[r2][col_idx] != 0) {
                    pivot_row = r2;
                    break;
                }
            }

            Machine.swapRow(A, b, i, pivot_row);

            if (A[i][col_idx] < 0) {
                var k2: usize = 0;
                while (k2 < cols) : (k2 += 1) {
                    A[i][k2] = -A[i][k2];
                }
                b[i] = -b[i];
            }

            var r3: usize = i + 1;
            while (r3 < rows) : (r3 += 1) {
                Machine.reduceRow(A, b, i, r3, cols);
            }

            i += 1;
            rank += 1;
        }

        if (rank > 0) {
            var ir: isize = @intCast(rank);
            while (ir > 0) : (ir -= 1) {
                const rr: usize = @intCast(ir - 1);
                var jr: usize = 0;
                while (jr < rr) : (jr += 1) {
                    Machine.reduceRow(A, b, rr, jr, cols);
                }
            }
        }

        return rank;
    }

    fn evaluateParamChoice(
        A: [][]i64,
        b: []i64,
        rows: usize,
        cols: usize,
        params: []const i64,
        param_sum: i64,
    ) i64 {
        const k = params.len;
        const base = cols - k;

        var sol: i64 = param_sum;

        var i: usize = 0;
        while (i < rows) : (i += 1) {
            var cc: i64 = 0;
            var j: usize = 0;
            while (j < k) : (j += 1) {
                cc += params[j] * A[i][base + j];
            }

            const s = b[i] - cc;
            const diag = A[i][i];
            if (diag == 0) {
                return INF;
            }

            if (@rem(s, diag) != 0) {
                return INF;
            }

            const a = @divTrunc(s, diag);
            if (a < 0) {
                return INF;
            }

            sol += a;
        }

        return sol;
    }

    fn dfsParams(
        A: [][]i64,
        b: []i64,
        c: []i64,
        rows: usize,
        cols: usize,
        k: usize,
        params: *[16]i64,
        idx: usize,
        partial_sum: i64,
        best: *i64,
    ) void {
        if (idx == k) {
            const total = Machine.evaluateParamChoice(A, b, rows, cols, params[0..k], partial_sum);
            if (total < best.*) {
                best.* = total;
            }
            return;
        }

        const base = cols - k;
        const col = base + idx;
        const ub = c[col];

        var v: i64 = 0;
        while (v <= ub) : (v += 1) {
            const new_sum = partial_sum + v;
            if (new_sum >= best.*) {
                break;
            }

            params.*[idx] = v;
            Machine.dfsParams(A, b, c, rows, cols, k, params, idx + 1, new_sum, best);
        }
    }

    fn minPressesForSystem(
        A: [][]i64,
        b: []i64,
        c: []i64,
        rows: usize,
        cols: usize,
    ) i64 {
        const k = cols - rows;

        if (k == 0) {
            return Machine.evaluateParamChoice(A, b, rows, cols, &[_]i64{}, 0);
        }

        var params = [_]i64{0} ** 16;
        var best: i64 = INF;

        Machine.dfsParams(A, b, c, rows, cols, k, &params, 0, 0, &best);
        return best;
    }

    fn buildTargetMask(self: *const Machine) Mask {
        var mask: Mask = 0;
        for (self.lights, 0..) |on, i| {
            if (on) {
                mask |= @as(Mask, 1) << @intCast(i);
            }
        }
        return mask;
    }

    fn buildButtonMasks(self: *const Machine) [15]Mask {
        var masks: [15]Mask = undefined;

        var i: usize = 0;
        while (i < self.buttons.len) : (i += 1) {
            var mask: Mask = 0;
            for (self.buttons[i]) |light_idx| {
                mask |= @as(Mask, 1) << @intCast(light_idx);
            }
            masks[i] = mask;
        }

        return masks;
    }

    fn isButtonPressed(combo: Mask, btn_idx: usize) bool {
        return ((combo >> @intCast(btn_idx)) & 1) != 0;
    }
};

pub fn solve(allocator: std.mem.Allocator) !void {
    const input = try helpers.readInputFile(allocator, "inputs/day10.txt");
    defer allocator.free(input);

    const machines = try parseMachines(allocator, input);
    defer {
        for (machines) |m| {
            m.deinit(allocator);
        }
        allocator.free(machines);
    }

    const part1: u64 = solvePart1(machines);
    const part2: u64 = try solvePart2(allocator, machines);

    std.debug.print("Part 1: {d}\nPart 2: {d}\n", .{ part1, part2 });
}

fn solvePart1(machines: []Machine) u64 {
    var tot: u64 = 0;
    for (machines) |machine| {
        tot += machine.solveLights();
    }

    return tot;
}

fn solvePart2(allocator: std.mem.Allocator, machines: []Machine) !u64 {
    var tot: u64 = 0;
    for (machines) |machine| {
        tot += try machine.solveJoltage(allocator);
    }

    return tot;
}

fn parseNumbers(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    var numbers = std.ArrayList(u8){};
    errdefer numbers.deinit(allocator);

    var iter = helpers.splitCommas(str);
    while (iter.next()) |num_str| {
        const num = try std.fmt.parseInt(u8, num_str, 10);
        try numbers.append(allocator, num);
    }

    return numbers.toOwnedSlice(allocator);
}

fn parseMachine(allocator: std.mem.Allocator, line: []const u8) !Machine {
    const lights_start = std.mem.indexOf(u8, line, "[") orelse return error.InvalidFormat;
    const lights_end = std.mem.indexOf(u8, line, "]") orelse return error.InvalidFormat;
    const lights_str = line[lights_start + 1 .. lights_end];

    var lights = try allocator.alloc(bool, lights_str.len);
    errdefer allocator.free(lights);

    for (lights_str, 0..) |c, i| {
        lights[i] = c == '#';
    }

    const joltage_start = std.mem.indexOf(u8, line, "{") orelse return error.InvalidFormat;
    const joltage_end = std.mem.indexOf(u8, line, "}") orelse return error.InvalidFormat;
    const joltage_str = line[joltage_start + 1 .. joltage_end];
    const joltage = try parseNumbers(allocator, joltage_str);
    errdefer allocator.free(joltage);

    const buttons_section = std.mem.trim(u8, line[lights_end + 1 .. joltage_start], " ");
    var buttons = std.ArrayList([]u8){};
    errdefer {
        for (buttons.items) |b| {
            allocator.free(b);
        }
        buttons.deinit(allocator);
    }

    var i: usize = 0;
    while (i < buttons_section.len) {
        if (buttons_section[i] == '(') {
            const close = std.mem.indexOfPos(u8, buttons_section, i, ")") orelse return error.InvalidFormat;
            const nums = try parseNumbers(allocator, buttons_section[i + 1 .. close]);
            try buttons.append(allocator, nums);
            i = close + 1;
        } else {
            i += 1;
        }
    }

    return Machine{
        .lights = lights,
        .buttons = try buttons.toOwnedSlice(allocator),
        .joltage = joltage,
    };
}

fn parseMachines(allocator: std.mem.Allocator, input: []const u8) ![]Machine {
    var machines = std.ArrayList(Machine){};
    errdefer {
        for (machines.items) |m| {
            m.deinit(allocator);
        }
        machines.deinit(allocator);
    }

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const machine = try parseMachine(allocator, line);
        try machines.append(allocator, machine);
    }

    return machines.toOwnedSlice(allocator);
}
