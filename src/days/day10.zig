const std = @import("std");
const helpers = @import("helpers");

const Machine = struct {
    const Mask = u16;

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

    fn solveJoltage(self: Machine, allocator: std.mem.Allocator) !u64 {
        const rowCount = self.joltage.len;
        const colCount = self.buttons.len;

        var system = try LinearSystem.init(allocator, rowCount, colCount);
        defer system.deinit();

        for (0..rowCount) |row| {
            system.setTarget(row, @intCast(self.joltage[row]));
        }

        for (self.buttons, 0..) |affectedLights, col| {
            var minJoltage: i64 = std.math.maxInt(i64);
            for (affectedLights) |lightIdx| {
                system.setCoefficient(lightIdx, col, 1);
                minJoltage = @min(minJoltage, self.joltage[lightIdx]);
            }

            if (affectedLights.len > 0) {
                system.setBound(col, minJoltage);
            }
        }

        system.reduce();

        const result = system.findMinNonNegativeSum() orelse return error.NoSolution;
        return @intCast(result);
    }
};

const LinearSystem = struct {
    const INF: i64 = std.math.maxInt(i64);

    matrix: [][]i64,
    rhs: []i64,
    bounds: []i64,
    rowCount: usize,
    colCount: usize,
    rank: usize,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !LinearSystem {
        const matrix = try allocator.alloc([]i64, rows);
        errdefer allocator.free(matrix);

        var initializedRows: usize = 0;
        errdefer {
            for (matrix[0..initializedRows]) |row| {
                allocator.free(row);
            }
        }

        for (matrix) |*row| {
            row.* = try allocator.alloc(i64, cols);
            initializedRows += 1;
            @memset(row.*, 0);
        }

        const rhs = try allocator.alloc(i64, rows);
        errdefer {
            for (matrix) |row| {
                allocator.free(row);
            }
            allocator.free(matrix);
        }
        @memset(rhs, 0);

        const bounds = try allocator.alloc(i64, cols);
        errdefer {
            for (matrix) |row| {
                allocator.free(row);
            }
            allocator.free(matrix);
            allocator.free(rhs);
        }
        @memset(bounds, 0);

        return LinearSystem{
            .matrix = matrix,
            .rhs = rhs,
            .bounds = bounds,
            .rowCount = rows,
            .colCount = cols,
            .rank = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *LinearSystem) void {
        for (self.matrix) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.matrix);
        self.allocator.free(self.rhs);
        self.allocator.free(self.bounds);
    }

    fn setCoefficient(self: *LinearSystem, row: usize, col: usize, value: i64) void {
        self.matrix[row][col] = value;
    }

    fn setTarget(self: *LinearSystem, row: usize, value: i64) void {
        self.rhs[row] = value;
    }

    fn setBound(self: *LinearSystem, col: usize, value: i64) void {
        self.bounds[col] = value;
    }

    fn reduce(self: *LinearSystem) void {
        self.rank = 0;
        var currentRow: usize = 0;
        var currentCol: usize = 0;

        while (currentRow < self.rowCount and currentCol < self.colCount) {
            const maybePivotCol = self.findPivotInSubmatrix(currentRow, currentCol);
            if (maybePivotCol == null) {
                break;
            }

            const pivotCol = maybePivotCol.?;

            self.swapCols(currentCol, pivotCol);

            const pivotRow = self.findPivotRow(currentRow, currentCol);
            self.swapRows(currentRow, pivotRow);

            if (self.matrix[currentRow][currentCol] < 0) {
                self.negateRow(currentRow);
            }

            self.eliminateBelow(currentRow, currentCol);

            currentRow += 1;
            currentCol += 1;
            self.rank += 1;
        }

        self.backEliminate();
    }

    fn findMinNonNegativeSum(self: *const LinearSystem) ?i64 {
        const freeVarCount = self.colCount - self.rank;

        if (freeVarCount == 0) {
            return self.evaluateWithFreeVars(&[_]i64{});
        }

        var freeVars = [_]i64{0} ** 16;
        var best: i64 = INF;

        self.searchFreeVarSpace(freeVarCount, &freeVars, 0, 0, &best);

        return if (best == INF) null else best;
    }

    fn swapRows(self: *LinearSystem, rowA: usize, rowB: usize) void {
        if (rowA == rowB) {
            return;
        }

        const tempRow = self.matrix[rowA];
        self.matrix[rowA] = self.matrix[rowB];
        self.matrix[rowB] = tempRow;

        const tempRhs = self.rhs[rowA];
        self.rhs[rowA] = self.rhs[rowB];
        self.rhs[rowB] = tempRhs;
    }

    fn swapCols(self: *LinearSystem, colA: usize, colB: usize) void {
        if (colA == colB) {
            return;
        }

        for (self.matrix) |row| {
            const temp = row[colA];
            row[colA] = row[colB];
            row[colB] = temp;
        }

        const tempBound = self.bounds[colA];
        self.bounds[colA] = self.bounds[colB];
        self.bounds[colB] = tempBound;
    }

    fn negateRow(self: *LinearSystem, row: usize) void {
        for (0..self.colCount) |col| {
            self.matrix[row][col] = -self.matrix[row][col];
        }
        self.rhs[row] = -self.rhs[row];
    }

    fn eliminateRow(self: *LinearSystem, pivotRow: usize, targetRow: usize, pivotCol: usize) void {
        const pivotVal = self.matrix[pivotRow][pivotCol];
        if (pivotVal == 0) {
            return;
        }

        const targetVal = self.matrix[targetRow][pivotCol];
        if (targetVal == 0) {
            return;
        }

        const gcd: i64 = @intCast(std.math.gcd(@abs(pivotVal), @abs(targetVal)));
        const scaleTarget = pivotVal;
        const scalePivot = -targetVal;

        for (0..self.colCount) |col| {
            const combined = scalePivot * self.matrix[pivotRow][col] + scaleTarget * self.matrix[targetRow][col];
            self.matrix[targetRow][col] = @divTrunc(combined, gcd);
        }

        const combinedRhs = scalePivot * self.rhs[pivotRow] + scaleTarget * self.rhs[targetRow];
        self.rhs[targetRow] = @divTrunc(combinedRhs, gcd);
    }

    fn eliminateBelow(self: *LinearSystem, pivotRow: usize, pivotCol: usize) void {
        for (pivotRow + 1..self.rowCount) |targetRow| {
            self.eliminateRow(pivotRow, targetRow, pivotCol);
        }
    }

    fn backEliminate(self: *LinearSystem) void {
        if (self.rank == 0) {
            return;
        }

        var pivotRow = self.rank;
        while (pivotRow > 0) {
            pivotRow -= 1;
            for (0..pivotRow) |targetRow| {
                self.eliminateRow(pivotRow, targetRow, pivotRow);
            }
        }
    }

    fn findPivotInSubmatrix(self: *const LinearSystem, startRow: usize, startCol: usize) ?usize {
        for (startCol..self.colCount) |col| {
            for (startRow..self.rowCount) |row| {
                if (self.matrix[row][col] != 0) {
                    return col;
                }
            }
        }
        return null;
    }

    fn findPivotRow(self: *const LinearSystem, startRow: usize, col: usize) usize {
        for (startRow..self.rowCount) |row| {
            if (self.matrix[row][col] != 0) {
                return row;
            }
        }
        return startRow;
    }

    fn evaluateWithFreeVars(self: *const LinearSystem, freeVars: []const i64) ?i64 {
        const freeVarCount = freeVars.len;
        const freeVarStart = self.colCount - freeVarCount;

        var total: i64 = 0;
        for (freeVars) |val| {
            total += val;
        }

        for (0..self.rank) |row| {
            var freeVarContribution: i64 = 0;
            for (freeVars, 0..) |freeVal, freeIdx| {
                freeVarContribution += freeVal * self.matrix[row][freeVarStart + freeIdx];
            }

            const numerator = self.rhs[row] - freeVarContribution;
            const diagonal = self.matrix[row][row];

            if (diagonal == 0) {
                return null;
            }
            if (@rem(numerator, diagonal) != 0) {
                return null;
            }

            const solution = @divTrunc(numerator, diagonal);
            if (solution < 0) {
                return null;
            }

            total += solution;
        }

        return total;
    }

    fn searchFreeVarSpace(
        self: *const LinearSystem,
        freeVarCount: usize,
        freeVars: *[16]i64,
        currentIdx: usize,
        partialSum: i64,
        best: *i64,
    ) void {
        if (currentIdx == freeVarCount) {
            if (self.evaluateWithFreeVars(freeVars[0..freeVarCount])) |total| {
                if (total < best.*) {
                    best.* = total;
                }
            }
            return;
        }

        const freeVarStart = self.colCount - freeVarCount;
        const boundCol = freeVarStart + currentIdx;
        const upperBound = self.bounds[boundCol];

        var value: i64 = 0;
        while (value <= upperBound) : (value += 1) {
            const newSum = partialSum + value;
            if (newSum >= best.*) break;

            freeVars[currentIdx] = value;
            self.searchFreeVarSpace(freeVarCount, freeVars, currentIdx + 1, newSum, best);
        }
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
