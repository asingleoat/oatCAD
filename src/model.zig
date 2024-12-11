const std = @import("std");

pub const unitTet = [_]f32{
    @sqrt(8.0) / 3.0,  0.0,               -1.0 / 3.0,
    @sqrt(2.0) / -3.0, @sqrt(2.0 / 3.0),  -1.0 / 3.0,
    @sqrt(2.0) / -3.0, -@sqrt(2.0 / 3.0), -1.0 / 3.0,
    0,                 0,                 1,
};
pub const unitTetSlice: []const f32 = &unitTet;

pub fn mkJsonArray(array: []const f32) ![]const u8 {
    var buffer: [1024]u8 = undefined; // Buffer to store the JSON string
    var stream = std.io.fixedBufferStream(buffer[0..]);
    const writer = stream.writer();
    stream.reset();

    // Start the JSON array for "vertices"
    try writer.writeAll("{ \"vertices\": [");

    // Append each number to the JSON array
    for (array, 0..) |value, index| {
        if (index != 0) {
            try writer.writeAll(", ");
        }
        // std.debug.print("{d}\n", .{value});
        try std.fmt.format(writer, "{d}", .{value}); // Format with 3 decimal places
    }
    // Close the "vertices" array
    try writer.writeAll("], \"indices\": [");

    // // Generate the "indices" array
    // for (0..(array.len)) |i| {
    //     if (i != 0) {
    //         try writer.writeAll(", ");
    //     }
    //     try std.fmt.format(writer, "{d}", .{i});
    // }
    try std.fmt.format(writer, "0, 1, 2, 1, 0, 3, 2, 1, 3, 2, 3, 0", .{});
    // Close the JSON object
    try writer.writeAll("] }");

    // Extract the JSON string from the buffer
    const json_string = buffer[0..stream.pos];
    // std.debug.print("JSON Array: {s}\n", .{json_string});
    return json_string;
}

pub const jsonTriangle =
    \\{
    \\  "vertices": [0, 0, 0, 1, 0, 0, 0, 1, 0],
    \\  "indices": [0, 1, 2]
    \\}
;

pub const jsonTriangle2 =
    \\{
    \\  "vertices": [0, 0, 0, -1, 0, 0, 0, 1, 0],
    \\  "indices": [0, 1, 2]
    \\}
;
