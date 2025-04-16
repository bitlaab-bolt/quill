# How to Install

Navigate to your project directory. e.g., `cd my_awesome_project`

### Install the Nightly Version

Fetch **quill** as external package dependency by running:

```sh
zig fetch --save \
https://github.com/bitlaab-bolt/quill/archive/refs/heads/main.zip
```

### Install the Release Version

Fetch **quill** as external package dependency by running:

```sh
zig fetch --save \
https://github.com/bitlaab-bolt/quill/archive/refs/tags/v0.0.0.zip
```

Make sure to edit `v0.0.0` with the latest release version.

## Import Module

Now, import **quill** as external package module to your project by coping following code:

```zig title="build.zig"
const quill = b.dependency("quill", .{});
exe.root_module.addImport("quill", quill.module("quill"));
lib.root_module.addImport("quill", quill.module("quill"));
```

**Remarks:** On windows, link **Lib C** with your project executable. e.g., `exe.linkLibC()`.
