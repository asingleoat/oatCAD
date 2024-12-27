const std = @import("std");
const math = std.math;
const stl = @import("stl");

pub const forced_dependency = "from seidel";

pub const Edge = struct {
    source: u32,
    sink: u32,
};

pub inline fn leadingBitSetP(value: u32) bool {
    return @clz(value) == 0;
}

pub inline fn validIndex(value: u32) bool {
    const invalid: u32 = 0xFFFFFFFF;
    return value != invalid;
}

// some fields are nullable, but we do it manually, rather than ?u32, to pack tighter. this
// technically restricts the size of triangulations we can compute to 2^32-2 instead of 2^32-1
pub const Trapezoid = struct {
    // index of vertex implicitly representing {top,bottom} side
    v_upper: u32,
    v_lower: u32,
    // nullable, concrete side or side at infinity
    e_left: Edge,
    e_right: Edge,
    // nullable, neighbor trapezoids
    n_upper_left: u32,
    n_upper_right: u32,
    n_lower_left: u32,
    n_lower_right: u32,
    // index into search tree
    node: u32,
    // inside: bool,
};
pub const TrapezoidStructure = struct {
    trapezoids: []Trapezoid,
    nextIndex: u32,
    // each vertex is inserted twice, once for each edge it is a member of
    // we track which vertices have been inserted and no-op on the second insert
    included: []bool,
    pub fn init(allocator: *std.mem.Allocator, numTrapezoids: u32) !TrapezoidStructure {
        const trapezoids = try allocator.alloc(Trapezoid, numTrapezoids);

        return TrapezoidStructure{
            .trapezoids = trapezoids,
            .nextIndex = 0,
        };
    }

    pub fn deinit(self: *TrapezoidStructure, allocator: *std.mem.Allocator) void {
        allocator.free(self.trapezoids);
    }
    pub fn insert_trapezoid(self: *TrapezoidStructure, trapezoid: Trapezoid) void {
        self.trapezoids[self.nextIndex] = trapezoid;
        self.nextIndex += 1;
    }
    // pub fn insert_edge(self: *TrapezoidStructure, edge: Edge) void {
    // const a =
    // }
};

pub const Node = struct {
    // if v_0 is a valid index, then this is an X node in sediel's terminology
    // and represents a segment which divides the tree left-right (along X)
    // else v_1 is the index of the vertex in a Y node which divides vertically
    v_0: u32,
    v_1: u32,
    // if the leading bit is 0, then the child is a node
    // else if the leading bit is 1, then the child is a trapezoid and the trailing bits give an
    // index into the trapezoid structure
    left_child: u32,
    right_child: u32,
};

pub const SearchTree = struct {
    nodes: []Node,
    nextIndex: u32,

    pub fn init(allocator: *std.mem.Allocator, numNodes: u32) !SearchTree {
        const nodes = try allocator.alloc(Node, numNodes);

        return SearchTree{
            .nodes = nodes,
            .nextIndex = 0,
        };
    }

    pub fn deinit(self: *SearchTree, allocator: *std.mem.Allocator) void {
        allocator.free(self.nodes);
    }
};
