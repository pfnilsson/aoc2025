const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const helpers_mod = b.createModule(.{
        .root_source_file = b.path("src/helpers.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Define the root Zig module for the executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "helpers", .module = helpers_mod },
        },
    });

    // Normal executable used for install/run
    const exe = b.addExecutable(.{
        .name = "aoc2025",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Forward args: `zig build run -- 1`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the AoC 2025 solver");
    run_step.dependOn(&run_cmd.step);

    // Build-on-save "check" step for ZLS
    // This lets ZLS run `zig build check` to surface full compiler errors.
    // ---------------------------------------------------------------------
    const exe_check = b.addExecutable(.{
        .name = "aoc2025",
        .root_module = exe_mod,
    });
    // NOTE: no b.installArtifact(exe_check);

    const check_step = b.step("check", "Check if aoc2025 compiles");
    check_step.dependOn(&exe_check.step);
}
