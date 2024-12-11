const std = @import("std");
const websocket = @import("websocket");
const Server = websocket.Server;
const model = @import("model.zig");
const ws = @import("websocket.zig");
const stl = @import("stl.zig");

const unitTetTries: [1]stl.TriSimple = .{stl.TriSimple{ .a = stl.va, .b = stl.vb, .c = stl.vc }};

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();

    std.debug.print("{any}\n", .{stl.convertToIndexedArray(allocator, &unitTetTries)});

    // this is the instance of your "global" struct to pass into your handlers
    var context = ws.Context{};

    const config = .{
        // .handshake_timeout_ms = null,
        .port = 9223,
        .max_headers = 10,
        .address = "127.0.0.1",
    };

    var server = try Server.init(allocator, config);
    defer server.deinit(allocator);

    // List to store active connections
    // var connections = std.ArrayList(websocket.Conn).init(allocator);

    try websocket.listen(ws.Handler, allocator, &context, .{
        .port = 9223,
        .max_headers = 10,
        .address = "127.0.0.1",
    });
}
