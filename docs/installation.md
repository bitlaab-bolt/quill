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
