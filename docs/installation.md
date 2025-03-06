# How to Install

## Installation

Navigate to your project directory. e.g., `cd my_awesome_project`

### Install the Nightly Version

Fetch quill as zig package dependency by running:

```sh
zig fetch --save \
https://github.com/bitlaab-bolt/quill/archive/refs/heads/main.zip
```

### Install a Release Version

Fetch quill as zig package dependency by running:

```sh
zig fetch --save \
https://github.com/bitlaab-bolt/quill/archive/refs/tags/"your-version".zip
```

Add quill as dependency to your project by coping following code on your project.

```zig title="build.zig"
const quill = b.dependency("quill", .{});
exe.root_module.addImport("quill", quill.module("quill"));
lib.root_module.addImport("quill", quill.module("quill"));
```

On windows, you must find:

```zig title="build.zig"
const exe = b.addExecutable(.{
    .name = "your_project",
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});
```

And, then paste the following code after that block:

```zig title="build.zig"
// Adding cross-platform dependency
switch (target.query.os_tag orelse builtin.os.tag) {
    .macos => {},
    .windows => exe.linkLibC(),
    else => @panic("Codebase is not tailored for this platform!")
}
```
