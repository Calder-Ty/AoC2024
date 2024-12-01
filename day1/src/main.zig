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
    var counter= std.AutoHashMap(usize, usize).init(allocator);

    var i: usize = 0;
    while (iter.next())|id| : (i += 1)  {
        if (i % 2 == 0) {
            try list1.append(try fmt.parseInt(usize, id, 10));
        } else {
            const entry = try counter.getOrPut(try fmt.parseInt(usize, id, 10));
            if (entry.found_existing) {
                entry.value_ptr.* += 1;
            } else {
                entry.value_ptr.* = 1;
            }
        }
    }
    sort.pdq(usize, list1.items, .{}, lessThan);

    // compute Similarity
    var sum: usize = 0;
    for (list1.items)|a| {
        const mult = counter.get(a) orelse 0;
        sum += mult * a;
    }

    std.debug.print("Similarit Metric is {d}", .{sum});
}

/// Load the Data from path
fn loadData(allocator:Allocator, path: []const u8) ![]u8 {
    const fd = try fs.cwd().openFile(path, .{});
    return try fd.readToEndAlloc(allocator, max_read);
}

fn lessThan( _: @TypeOf(.{}), a: usize, b:usize) bool {
    return a < b;
}
