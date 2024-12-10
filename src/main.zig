const std = @import("std");
const websocket = @import("websocket");
const Conn = websocket.Conn;
const Message = websocket.Message;
const Handshake = websocket.Handshake;
const Server = websocket.Server;

// Define a struct for "global" data passed into your websocket handler
// This is whatever you want. You pass it to `listen` and the library will
// pass it back to your handler's `init`. For simple cases, this could be empty
const Context = struct {};

fn sendMultiples(conn: *Conn) !void {
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

// Handler for client connections
fn connectionHandler(conn: websocket.Connection, allocator: *const std.mem.Allocator) !void {
    defer conn.close();

    while (true) {
        const message = try conn.readMessage(allocator);
        defer allocator.free(message.data);

        std.debug.print("Received: {s}\n", .{message.data});
        if (message.opcode == websocket.Opcode.Close) break;
    }
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();

    // this is the instance of your "global" struct to pass into your handlers
    var context = Context{};

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

    try websocket.listen(Handler, allocator, &context, .{
        .port = 9223,
        .max_headers = 10,
        .address = "127.0.0.1",
    });
}

const Handler = struct {
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
        try sendMultiples(self.conn);
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
