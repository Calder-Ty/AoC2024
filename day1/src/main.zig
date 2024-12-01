const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const sort = std.sort;
const Allocator = std.mem.Allocator;

const max_read=15*1024;


pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const rawdata = try loadData(allocator, "data/prod.txt");

    var iter = std.mem.tokenizeAny(u8, rawdata, "\n ");
    // input is C, C \n
    var list1 = std.ArrayList(usize).init(allocator);
    var list2 = std.ArrayList(usize).init(allocator);

    var i: usize = 0;
    while (iter.next())|id| : (i += 1)  {
        if (i % 2 == 0) {
            try list1.append(try fmt.parseInt(usize, id, 10));
        } else {
            try list2.append(try fmt.parseInt(usize, id, 10));
        }
    }
    sort.pdq(usize, list1.items, .{}, lessThan);
    sort.pdq(usize, list2.items, .{}, lessThan);

    // compute distances
    var sum: usize = 0;
    for (list1.items, list2.items )|a, b| {
        if (a > b) {
            sum += a - b;
        } else {
            sum += b - a;
        }
    }

    std.debug.print("Total Distance is {d}", .{sum});
}

/// Load the Data from path
fn loadData(allocator:Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}

fn lessThan( _: @TypeOf(.{}), a: usize, b:usize) bool {
    return a < b;
}
