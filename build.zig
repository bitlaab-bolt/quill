const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // C header translation, pointing at your existing include dir
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("libs/src/header.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    translate_c.addIncludePath(b.path("libs/include"));
    const sqlite3_mod = translate_c.createModule();

    // Exposing as a dependency for other projects
    const pkg = b.addModule("quill", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true, // required to compile sqlite3.c
    });
    pkg.addIncludePath(b.path("libs/include"));
    pkg.addCSourceFile(.{
        .file = b.path("libs/src/sqlite3.c"),
        .flags = &.{"-DSQLITE_ENABLE_JSON1"},
    });
    pkg.addImport("sqlite3", sqlite3_mod);

    const main = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{.name = "quill", .root_module = main});

    switch (target.result.os.tag) {
        .macos, .windows, .linux => {},
        else => @panic("Codebase is not tailored for this platform!"),
    }

    exe.root_module.addImport("quill", pkg);
    // Only needed if main.zig itself uses sqlite directly:
    // exe.root_module.addImport("sqlite3", sqlite3_mod);

    const jsonic = b.dependency("jsonic", .{});
    pkg.addImport("jsonic", jsonic.module("jsonic"));
    exe.root_module.addImport("jsonic", jsonic.module("jsonic"));

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}