const std = @import("std");
const builtin = @import("builtin");


pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSafe
    });

    // Exposing as a dependency for other projects
    const pkg = b.addModule("quill", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize
    });

    pkg.addIncludePath(b.path("libs/include"));
    pkg.addCSourceFile(.{.file = b.path("libs/src/sqlite3.c"), .flags = &.{}});

    // Making executable for this project
    const exe = b.addExecutable(.{
        .name = "quill",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Adding cross-platform dependency
    switch (target.query.os_tag orelse builtin.os.tag) {
        .macos => {},
        .windows => exe.linkLibC(),
        else => @panic("Codebase is not tailored for this platform!")
    }

    // Internal package dependencies
    exe.root_module.addImport("quill", pkg);

    // External package dependencies
    const jsonic = b.dependency("jsonic", .{});
    pkg.addImport("jsonic", jsonic.module("jsonic"));
    exe.root_module.addImport("jsonic", jsonic.module("jsonic"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&b.addRunArtifact(exe).step);
}
