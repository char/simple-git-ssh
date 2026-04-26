const std = @import("std");
const shlex = @import("shlex");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const cmd = init.environ_map.get("SSH_ORIGINAL_COMMAND") orelse {
        std.log.err("SSH_ORIGINAL_COMMAND not set", .{});
        std.process.exit(1);
    };

    const tokens = shlex.split(allocator, cmd, false, true) catch |err| {
        std.log.err("failed to parse SSH_ORIGINAL_COMMAND: {}", .{err});
        std.process.exit(1);
    };
    defer {
        for (tokens) |t| allocator.free(t);
        allocator.free(tokens);
    }

    const is_receive_pack = std.mem.eql(u8, tokens[0], "git-receive-pack");
    const is_upload_pack = std.mem.eql(u8, tokens[0], "git-upload-pack");

    if (tokens.len < 2 or (!is_receive_pack and !is_upload_pack)) {
        std.log.err("disallowed command: {s}", .{cmd});
        std.process.exit(1);
    }

    const repo_path_raw = tokens[tokens.len - 1];

    const home = init.environ_map.get("HOME") orelse {
        std.log.err("HOME not set", .{});
        std.process.exit(1);
    };

    const repo_path = try expandPath(allocator, home, repo_path_raw);
    defer allocator.free(repo_path);

    if (!std.mem.startsWith(u8, repo_path, home) or
        (repo_path.len > home.len and repo_path[home.len] != '/'))
    {
        std.log.err("repo path escapes HOME: {s}", .{repo_path_raw});
        std.process.exit(1);
    }

    if (is_receive_pack) {
        std.Io.Dir.accessAbsolute(io, repo_path, .{}) catch {
            std.log.info("auto-initializing bare repo at {s}", .{repo_path});
            std.Io.Dir.createDirPath(.cwd(), io, repo_path) catch |err| {
                std.log.err("failed to create repo directory: {}", .{err});
                std.process.exit(1);
            };
            const result = try std.process.run(allocator, io, .{
                .argv = &.{ "git", "init", "--bare", repo_path },
            });
            defer allocator.free(result.stdout);
            defer allocator.free(result.stderr);
            if (result.term != .exited or result.term.exited != 0) {
                std.log.err("git init --bare failed: {s}", .{result.stderr});
                std.process.exit(1);
            }
        };
    }

    return execGitShell(allocator, io, cmd);
}

// im pretty sure this is what git expand user path does. wordexp from posix is overkill
fn expandPath(allocator: std.mem.Allocator, home: []const u8, path: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, path, "~/")) {
        return std.fs.path.resolve(allocator, &.{ home, path[2..] });
    } else if (std.mem.eql(u8, path, "~")) {
        return allocator.dupe(u8, home);
    } else {
        return std.fs.path.resolve(allocator, &.{ home, path });
    }
}

fn execGitShell(allocator: std.mem.Allocator, io: std.Io, cmd: []const u8) !void {
    const argv = try allocator.dupe([]const u8, &.{ "git-shell", "-c", cmd });
    defer allocator.free(argv);
    return std.process.replace(io, .{ .argv = argv });
}
