# Data Types

SQLite database engine primarily stores data into the database file as `Integer`, `Float`, `Text`, or `Blob`. To incorporate this, Quill provides some custom data types for data binding and retrieval to ensure consistency, ease of use, compile-time type checks and code generations.

## Scaler Types

- **Int** - Represents an `i64` integer number.
- **Bool** - Represents a `bool` of `true` or `false` value.
- **Float** - Represents a `f64` floating point number.
- **Slice** - Represents a slice of `[]const u8` value.

## User Defined Types

### Any()

TypeCasts SQLite column data into a given data type when evaluated.


**Example 01:** Converts `Text` data from a column into Zig's `struct`.

```zig
const User = struct { name: []const u8, age: u8 };
const Result = Any(User);
```

**Example 02:** Converts `Text` data from a column into Zig's `enum`.

```zig
const Gender = enum { Male, Female };
const Result = Any(Gender);
```

**Remarks:** In both of these cases `Text` data of the column must be stored as stringified JSON.

### CastInto()

TypeCasts a given data type into SQLite column data when evaluated.

**Example 01:** Converts `enum` data into a SQLite `Integer` column.

```zig
const Gender = enum { Male, Female };
const Result = CastInfo(.Int, Gender);
```

**Example 02:** Converts `enum` data into a SQLite `Text` column.

```zig
const Gender = enum { Male, Female };
const Result = CastInfo(.Text, Gender);
```

**Example 03:** Converts `struct` data into a SQLite `Text` column.

```zig
const User = struct { name: []const u8, age: u8 };
const Result = CastInfo(.Text, User);
```

**Remarks:** As of now, `CastInto()` doesn't support `.Blob` conversion for user defined types.

## Record Schema

A record contains multiple fields with their corresponding data types. Quill's record is just a synonym for SQLite **Row** and the fields are synonym for SQLite **Column**'s.

To reduce development time, Quill automatically TypeCasts between Zig and SQLite data. Use following `DataType` format for the appropriate use cases.

### Model

Contains type definitions that are automatically casts into SQLite complaint data types. All available type combinations are:

```zig title="schema/user.zig"
const Gender = enum { Male, Female };
const Social = struct { website: []const u8, username: [] const u8 };

pub const ModelUser = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    name1: Dt.CastInto(.Text, Dt.Slice),
    name2: ?Dt.CastInto(.Text, Dt.Slice),
    balance1: Dt.Float,
    balance2: ?Dt.Float,
    age1: Dt.Int,
    age2: ?Dt.Int,
    verified1: Dt.Bool,
    verified2: ?Dt.Bool,
    gender1: Dt.CastInto(.Int, Gender),
    gender2: ?Dt.CastInto(.Int, Gender),
    gender3: Dt.CastInto(.Text, Gender),
    gender4: ?Dt.CastInto(.Text, Gender),
    about1: Dt.CastInto(.Blob, Dt.Slice),
    about2: ?Dt.CastInto(.Blob, Dt.Slice),
    social1: Dt.CastInto(.Text, Social),
    social2: ?Dt.CastInto(.Text, Social),
    social3: Dt.CastInto(.Text, []const Social),
    social4: ?Dt.CastInto(.Text, []const Social)
};
```

### View

Contains type definitions that are automatically casts into Zig complaint data types. All available type combinations are:

```zig title="schema/user.zig"
const Gender = enum { Male, Female };
const Social = struct { website: []const u8, username: [] const u8 };

pub const ViewUser = struct {
    uuid: Dt.Slice,
    name1: Dt.Slice,
    name2: ?Dt.Slice,
    balance1: Dt.Float,
    balance2: ?Dt.Float,
    age1: Dt.Int,
    age2: ?Dt.Int,
    verified1: Dt.Bool,
    verified2: ?Dt.Bool,
    gender1: Dt.Any(Gender),
    gender2: ?Dt.Any(Gender),
    gender3: Dt.Any(Gender),
    gender4: ?Dt.Any(Gender),
    about1: Dt.Slice,
    about2: ?Dt.Slice,
    social1: Dt.Any(Social),
    social2: ?Dt.Any(Social),
    social3: Dt.Any([]const Social),
    social4: ?Dt.Any([]const Social)
};
```

### Filter

Contains limited number of type definitions that are automatically casts into SQL statement complaint data types. All available type combinations are:

```zig title="schema/user.zig"
pub const FilterUser = struct {
    uuid: Dt.Slice,
    name1: []const Dt.Slice,
    age1: Dt.Int,
    balance1: []const Dt.Int,
};
```

**Remarks:** Only use `Int`, `Slice`, `[]const Int`, and `[]const Slice`.

## Schema Directory and Naming Conversions

For a large codebase, use following convention for structural consistence.

```txt
schema
├── customer.zig
├── user.zig
└── ...
```

Create a `schema` directory in your project `src` directory. Within your schema directory create a file such as `user.zig` to represent a database container (Table). Now declare all of your Model, View, and Filter structure within this file.

```zig title="user.zig"
pub const Model = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    name: Dt.CastInto(.Text, Dt.Slice),
    balance: Dt.Float,
    age: Dt.Int
};

pub const View = struct {
    uuid: Dt.Slice,
    name: Dt.Slice,
    balance: Dt.Float,
    age: Dt.Int
};

pub const ModelProfile = struct {
    uuid: Dt.CastInto(.Blob, Dt.Slice),
    name: Dt.CastInto(.Text, Dt.Slice)
};

pub const FilterModelProfile = struct {
    uuid: Dt.slice
};

pub const ViewProfile = struct {
    uuid: Dt.Slice,
    name: Dt.Slice,
};

pub const FilterViewProfile = struct {
    balance: Dt.Int,
    age: []const Dt.Int
};
```