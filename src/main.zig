const std = @import("std");
const testing = std.testing;
const websocket = @import("websocket");
const Server = websocket.Server;
const model = @import("model.zig");
const ws = @import("websocket.zig");
const stl = @import("stl.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();

    // hardcoded tetrahedron test
    // const indexArray = try stl.convertToIndexedArray(allocator, &model.unitTetTries);
    // const jsonPayload = try indexArray.toJson(allocator);
    // defer allocator.free(jsonPayload);

    // const stl_model = try stl.readStl(std.fs.cwd(), allocator, "Bunny.stl"); // hardcoded path to untracked STL because this is development
    // const stl_tris = try stl.triListToSimpleArray(allocator, stl_model.tris);
    // const indexArray = try stl.convertToIndexedArray(allocator, stl_tris);
    // std.debug.print("idxs: {any}\n", .{(indexArray.idxs.len)});
    // std.debug.print("verts: {any}\n", .{(indexArray.verts.len)});
    // std.debug.print("sample vert: {any}\n", .{(indexArray.verts[0])});
    // const jsonPayload = try indexArray.toJson(allocator);

    const polyline = try stl.circle(allocator, 1, 0.5);
    polyline.move(stl.V3{ .x = 0, .y = 0, .z = 0.5 });
    const jsonPayload = try polyline.toJson(allocator);

    std.debug.print("{d}\n", .{jsonPayload.len});
    defer allocator.free(jsonPayload);

    var context = ws.Context{
        .payload = jsonPayload,
    };

    const config = .{
        // .handshake_timeout_ms = null,
        .port = 9223,
        .max_headers = 10,
        .address = "127.0.0.1",
    };

    var server = try Server.init(allocator, config);
    defer server.deinit(allocator);

    try websocket.listen(ws.Handler, allocator, &context, .{
        .port = 9223,
        .max_headers = 10,
        .address = "127.0.0.1",
    });
}

test "main memory-leaks" {
    const allocator = testing.allocator;

    var stl_model = try stl.readStl(std.fs.cwd(), allocator, "Bunny.stl"); // hardcoded path to untracked STL because this is development
    defer stl_model.tris.deinit(allocator);

    const stl_tris = try stl.triListToSimpleArray(allocator, stl_model.tris);
    defer allocator.free(stl_tris);

    const indexArray = try stl.convertToIndexedArray(allocator, stl_tris);
    // TODO write a nicer deinit
    defer allocator.free(indexArray.verts);
    defer allocator.free(indexArray.idxs);

    std.debug.print("idxs: {any}\n", .{(indexArray.idxs.len)});
    std.debug.print("verts: {any}\n", .{(indexArray.verts.len)});
    std.debug.print("sample vert: {any}\n", .{(indexArray.verts[0])});
    const jsonPayload = try indexArray.toJson(allocator);

    std.debug.print("{d}\n", .{jsonPayload.len});
    defer allocator.free(jsonPayload);
}
