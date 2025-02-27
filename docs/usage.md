# How to use

First import Jsonic on your zig file.

```zig
const jsonic = @import("jsonic");
```

Initiate a General Propose Allocator (GPA) on main function.

```zig
var gpa_mem = std.heap.GeneralPurposeAllocator(.{}){};
defer debug.assert(gpa_mem.deinit() == .ok);
const heap = gpa_mem.allocator();
```

## Supported Data Type

To parse a JSON string into a Zig struct, only use following data types:

- `[]const u8` - For representing text data
- `i64` - For representing integer number
- `f64` - For representing floating point number
- `bool` - For representing boolean value
- `T` or `[]const T` - For representing user defined type
- `?T` or `?[]const T` - For representing optional user defined type

## Static JSON

```zig
const User = struct { name: []const u8, age: u8 };

const static_str = "{ \"name\": \"John Doe\", \"age\": 40 }";
const src = try heap.alloc(u8, static_str.len);
defer heap.free(src);
std.mem.copyForwards(u8, src, static_str);

const data = try jsonic.StaticJson.parse(User, heap, src);
std.debug.print(
    "Structure Data - name: {s} age: {d}\n", .{data.name, data.age}
);

const json_str = try jsonic.StaticJson.stringify(heap, data);
defer heap.free(json_str);

std.debug.print("Stringify Data - {s}\n", .{json_str});
try jsonic.free(heap, data);
```

## Dynamic JSON

### Array

```zig
const static_str = "[\"John Doe\", 40]";
const src = try heap.alloc(u8, static_str.len);
defer heap.free(src);
std.mem.copyForwards(u8, src, static_str);

var dyn_json = try jsonic.DynamicJson.init(heap, src, .{});
defer dyn_json.deinit();

const json_data = dyn_json.data().array;
const item_1 = json_data.items[0].string;
const item_2 = json_data.items[1].integer;
std.debug.print("Array Item - Name: {s} Age: {}\n", .{item_1, item_2});
```

### Convert Array Value Into a Slice Type

**Remarks:** Unlike JSON array, `jsonic` only supports array with same type. e.g., `[]const User` or `[]const ?User`.

```zig
const SliceType = []const[]const u8;
const static_str = "[\"John Doe\", \"Jane Doe\"]";
const src = try heap.alloc(u8, static_str.len);
defer heap.free(src);
std.mem.copyForwards(u8, src, static_str);

var dyn_json = try jsonic.DynamicJson.init(heap, src, .{});
defer dyn_json.deinit();

const value = dyn_json.data();
const result = try jsonic.DynamicJson.parseInto(SliceType, heap, value);
const str = try jsonic.StaticJson.stringify(heap, result);
defer heap.free(str);

debug.print("Stringify Result:\n{s}\n", .{str});
try jsonic.free(heap, result);
```

### Object

```zig
const static_str =
\\ {
\\      "name": "Jane Doe",
\\      "age": 30,
\\      "hobby": ["reading", "fishing"],
\\      "feelings": {
\\          "fear": 75,
\\          "joy": 25
\\      }
\\ }
;

const static_input = try heap.alloc(u8, static_str.len);
mem.copyForwards(u8, static_input, static_str);
defer heap.free(static_input);

var json_value = try jsonic.DynamicJson.init(heap, static_input, .{});
defer json_value.deinit();

const value = json_value.data().object;
const joy = value.get("feelings").?.object.get("joy").?.integer;
std.debug.print("Joy: {d}\t", .{joy});

const hobby = value.get("hobby").?.array.items[1].string;
std.debug.print("Hobby: {s}\n\n", .{hobby});
```

### Convert Object Value Into a Struct


```zig
const Feelings = struct { fear: i64, joy: i64 };

const User = struct {
    name: []const u8,
    age: i64,
    hobby: []const[]const u8,
    feelings: Feelings,
};

const static_str =
\\ {
\\      "name": "Jane Doe",
\\      "age": 30,
\\      "hobby": ["reading", "fishing"],
\\      "feelings": {
\\          "fear": 75,
\\          "joy": 25
\\      }
\\ }
;

const static_input = try heap.alloc(u8, static_str.len);
mem.copyForwards(u8, static_input, static_str);
defer heap.free(static_input);

var json_value = try jsonic.DynamicJson.init(heap, static_input, .{});
defer json_value.deinit();

const src = json_value.data();
const result = try jsonic.DynamicJson.parseInto(User, heap, src);
const str = try jsonic.StaticJson.stringify(heap, result);
defer heap.free(str);

debug.print("Stringify Result:\n{s}\n", .{str});
try jsonic.free(heap, result);
```
