const std = @import("std");

const Person = struct {
    name: []const u8,
    age: u8,
};

test "play" {
    //var person = Person{ .name = "Alice", .age = 25 };

    var person = std.mem.zeroes(Person);

    // Field name as a string
    // const field_name = "age";

    const struct_info = @typeInfo(Person).@"struct";

    var x: u8 = 30;
    _ = &x;

    // Set value using @field
    @field(person, struct_info.fields[1].name) = x;

    std.log.warn("Updated Person: {s}, Age: {}\n", .{ person.name, person.age });
}