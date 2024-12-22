const std = @import("std");
const stl = @import("stl.zig");

pub fn triangulate(allocator: std.mem.Allocator, r: std.Random.Random, polygon: stl.Polyline) !void {
    const root: usize = 0;
    // _ = root;
    const n = polygon.verts.len - 1;

    const edges = try allocator.alloc(Edge, n);
    for (0..edges.len) |i| {
        edges[i] = .{
            .v = i,
            .leftParent = null,
            .rightParent = null,
        };
    }
    const shuffled_edges = try allocator.alloc(Edge, n);
    @memcpy(shuffled_edges, edges);
    std.Random.shuffle(r, Edge, shuffled_edges);

    // query structure
    const treeBuf = try allocator.alloc(TreeNode, n + 1);

    // vertex insertion checklist
    const vertBuf = try allocator.alloc(bool, n + 1);
    @memset(vertBuf, false);

    // edge insertion checklist
    const edgeChecklist = try allocator.alloc(bool, n);
    @memset(edgeChecklist, false);

    var tree = BinaryTree.init(treeBuf, vertBuf);
    // _ = tree;
    try insertEdge(&tree, root, polygon.verts, edges[0]);
    std.debug.print("{any}\n\n", .{edges});
    std.debug.print("{any}\n\n", .{shuffled_edges});
    // std.debug.print("{any}\n\n", .{tree});
    for (1..logstar(polygon.verts.len - 1)) |h| {
        for ((N(n, h - 1) + 1)..(N(n, h) + 1)) |i| {
            _ = i;
        }
    }

    // Seidel's paper uses a real valued log2. If we do the integer log2 instead, then the for-loop in step (4) is always empty and we can skip it.
    // var i: usize = N(n, logstar(n));
    // while (i < n) {
    // i += 1;
    // }
}

pub fn insertEdge(tree: *BinaryTree, parent: usize, verts: []stl.V3, e: Edge) !void {
    if (verts[e.v].lessThan(verts[e.v + 1])) {
        std.debug.print("{any}\n\n", .{e});
        _ = try tree.*.addNode(parent, NodeKind{ .vertex = e.v + 1 });
    } else {
        _ = try tree.*.addNode(parent, NodeKind{ .vertex = e.v });
    }

    // _ = tree;
    // _ = e;
}

pub fn N(n: usize, h: u64) usize {
    return divCeil(usize, n, iterLog(usize, h, n));
}

pub fn divCeil(comptime T: type, a: T, b: T) T {
    if (b > 0) {
        return (a + (b - 1)) / b;
    } else if (b < 0) {
        return (a + (b + 1)) / b;
    } else {
        @panic("Division by zero");
    }
}

pub fn iterLog(comptime T: type, h: T, n: T) T {
    var r: T = n;
    for (0..@intCast(h)) |i| {
        _ = i;
        r = log2(T, r);
    }
    return @max(1, r);
}

// integer log2, might want to use floating log2?
pub fn log2(comptime T: type, x: T) T {
    return (@sizeOf(T) * 8 - 1) - @clz(x);
}

pub fn logstar(x: u64) u64 {
    if (x > 65536) {
        return 5;
    } else if (x > 16) {
        return 4;
    } else if (x > 4) {
        return 3;
    } else if (x > 2) {
        return 2;
    } else if (x > 1) {
        return 1;
    } else {
        return 0;
    }
}

pub const Trapezoid = struct {
    left: ?Edge,
    right: ?Edge,
    // vertex above, spiritually an upper/lower limit y-value, but we break ties
    // lexicographically so we need the whole 2D point
    v_upper: ?usize,
    v_lower: ?usize,
    // indices of the at-most two neighboring trapezoids above/below
    t_upper_0: ?usize,
    t_upper_1: ?usize,
    t_lower_0: ?usize,
    t_lower_1: ?usize,
    // index of trap's node in the query structure
    node: ?usize,
};

// Implicit representation of an edge given by the index of the first vertex
pub const Edge = struct {
    v: usize,
    leftParent: ?usize,
    rightParent: ?usize,
};

pub fn isLeftOf(p: []stl.V3, vq: stl.V3, e: Edge) bool {
    const v0 = p[e.v];
    const v1 = p[e.v + 1];
    // compute the cross product determinant:
    const cross = (v1.x - v0.x) * (vq.y - v0.y) - (v1.y - v0.y) * (vq.x - v0.x);

    // if cross >= 0, point p is to the left of line segment.
    return cross >= 0;
}

pub const NodeKind = union(enum) {
    edge: Edge,
    vertex: usize,
    trap: usize,
};

pub const TreeNode = struct {
    kind: NodeKind,
    parent: ?usize,
    leftChild: ?usize, // left/lower
    rightChild: ?usize, // right/upper
    trap: ?usize,
};

pub const BinaryTree = struct {
    nodes: []TreeNode,
    nextIndex: usize, // Next available index in the array
    contains: []bool,

    pub fn init(buffer: []TreeNode, containsBuf: []bool) BinaryTree {
        return BinaryTree{ .nodes = buffer, .nextIndex = 0, .contains = containsBuf };
    }

    pub fn locateVertex(
        self: *BinaryTree,
        p: []stl.V3,
        v: stl.V3,
        start: usize,
    ) usize {
        const node = self.nodes[start];
        switch (node.kind) {
            .vertex => |i| {
                if (v.lessThan(p[i])) {
                    self.locateVertex(p, v, node.leftChild);
                } else {
                    self.locateVertex(p, v, node.rightChild);
                }
            },
            .edge => |e| {
                if (isLeftOf(p, v, e)) {
                    self.locateVertex(p, v, node.leftChild);
                } else {
                    self.locateVertex(p, v, node.rightChild);
                }
            },
            .trap => |t| {
                return t;
            },
        }
    }

    pub fn addNode(
        self: *BinaryTree,
        parent: usize,
        nodeKind: NodeKind,
    ) !usize {
        if (self.nextIndex >= self.nodes.len) return error.OutOfSpace;
        switch (nodeKind) {
            .vertex => |i| self.contains[i] = true,
            .edge => {},
            .trap => {},
        }

        // TODO: locate parents and update their children indexes

        self.nodes[self.nextIndex] = TreeNode{
            .parent = parent,
            .kind = nodeKind,
            .leftChild = null,
            .rightChild = null,
            .trap = null,
        };
        const currentIndex = self.nextIndex;
        self.nextIndex += 1;
        return currentIndex;
    }

    pub fn setChildren(self: *BinaryTree, parentIndex: usize, left: ?usize, right: ?usize) void {
        self.nodes[parentIndex].leftChild = left;
        self.nodes[parentIndex].rightChild = right;
    }

    // pub fn traverseInOrder(
    //     self: *BinaryTree,
    //     nodeIndex: usize,
    //     visit: fn (*TreeNode) void,
    // ) void {
    //     const node = &self.nodes[nodeIndex];
    //     if (node.leftChild) |left| self.traverseInOrder(left, visit);

    //     visit(node);

    //     if (node.rightChild) |right| self.traverseInOrder(right, visit);
    // }
};
