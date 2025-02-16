const std = @import("std");
const websocket = @import("websocket");
const Conn = websocket.Conn;
const Message = websocket.Message;
const Handshake = websocket.Handshake;
const model = @import("model.zig");
const stl = @import("stl.zig");

pub const Context = struct {
    payload: []const u8,
};

pub fn sendFixedGeometry(conn: *Conn, payload: []const u8) !void {
    std.debug.print("sending geometry\n", .{});

    // while (true) {
    //     // Delay for 1 second
    //     try conn.writeText(jsonTriangle);
    //     std.time.sleep(16_666_667);
    // try conn.writeText(jsonTriangle2);
    //     std.time.sleep(16_666_667);
    // }

    // const jsonTet = try model.mkJsonArray(model.unitTetSlice);
    try conn.writeText(payload);
}

pub fn sendMultiples(conn: *Conn) !void {
    var buffer: [128]u8 = undefined;
    var stream = std.io.fixedBufferStream(buffer[0..]);
    const writer = stream.writer();

    var counter: u32 = 0;
    while (true) {
        // Delay for 1 second
        std.time.sleep(1_000_000_000);

        // Send update to all clients
        if (!conn.closed) {
            std.debug.print("looping: {d}\n", .{counter});

            stream.reset();

            try std.fmt.format(writer, "Custom format: {d}", .{counter});
            const result = buffer[0..stream.pos];

            try conn.writeText(result);
        }
        counter += 1;
    }
}

pub fn connectionHandler(conn: websocket.Connection, allocator: *const std.mem.Allocator) !void {
    defer conn.close();

    while (true) {
        const message = try conn.readMessage(allocator);
        defer allocator.free(message.data);

        std.debug.print("Received: {s}\n", .{message.data});
        if (message.opcode == websocket.Opcode.Close) break;
    }
}

pub const Handler = struct {
    conn: *Conn,
    context: *Context,

    pub fn init(h: Handshake, conn: *Conn, context: *Context) !Handler {
        // `h` contains the initial websocket "handshake" request
        // It can be used to apply application-specific logic to verify / allow
        // the connection (e.g. valid url, query string parameters, or headers)

        _ = h; // we're not using this in our simple case

        return Handler{
            .conn = conn,
            .context = context,
        };
    }

    // optional hook that, if present, will be called after initialization is complete
    pub fn afterInit(self: *Handler) !void {
        try sendFixedGeometry(self.conn, self.context.payload);
    }

    pub fn handle(self: *Handler, message: Message) !void {
        // const my_message[] = [127];
        const my_message: [3]u8 = [_]u8{ 1, 2, 3 };

        const data = message.data;
        std.debug.print("Message: {s}\n", .{data});
        try self.conn.writeBin(&my_message); // echo the message back
    }

    // called whenever the connection is closed, can do some cleanup in here
    pub fn close(_: *Handler) void {}
};
