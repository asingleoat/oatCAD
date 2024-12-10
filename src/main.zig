const std = @import("std");
const websocket = @import("websocket");
const Conn = websocket.Conn;
const Message = websocket.Message;
const Handshake = websocket.Handshake;

// Define a struct for "global" data passed into your websocket handler
// This is whatever you want. You pass it to `listen` and the library will
// pass it back to your handler's `init`. For simple cases, this could be empty
const Context = struct {};

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();

    // this is the instance of your "global" struct to pass into your handlers
    var context = Context{};

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
    // pub fn afterInit(self: *Handler) !void {}

    pub fn handle(self: *Handler, message: Message) !void {
        const my_message = "hello";

        const data = message.data;
        std.debug.print("Message: {s}\n", .{data});
        try self.conn.writeText(my_message); // echo the message back

    }

    // called whenever the connection is closed, can do some cleanup in here
    pub fn close(_: *Handler) void {}
};
