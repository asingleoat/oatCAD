const std = @import("std");
const stl = @import("stl.zig");

pub const unitTetTries: [4]stl.TriSimple = .{ stl.TriSimple{ .a = stl.va, .b = stl.vb, .c = stl.vc }, stl.TriSimple{ .a = stl.vb, .b = stl.va, .c = stl.vd }, stl.TriSimple{ .a = stl.vc, .b = stl.vb, .c = stl.vd }, stl.TriSimple{ .a = stl.vc, .b = stl.vd, .c = stl.va } };

pub const unitTet = [_]f32{
    @sqrt(8.0) / 3.0,  0.0,               -1.0 / 3.0,
    @sqrt(2.0) / -3.0, @sqrt(2.0 / 3.0),  -1.0 / 3.0,
    @sqrt(2.0) / -3.0, -@sqrt(2.0 / 3.0), -1.0 / 3.0,
    0,                 0,                 1,
};
pub const unitTetSlice: []const f32 = &unitTet;

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
