const std = @import("std");
const rlz = @import("raylib_zig");

const GAME_NAME = "Darts 2 million";

const SCREEN_WIDTH = 1200;
const SCREEN_HEIGHT = 750;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const board_salt = b.option([]const u8, "board-salt", "The salt to use when uploading to the server") orelse "salty";

    const options = b.addOptions();
    options.addOption([:0]const u8, "GAME_NAME", GAME_NAME);
    options.addOption(comptime_int, "SCREEN_WIDTH", SCREEN_WIDTH);
    options.addOption(comptime_int, "SCREEN_HEIGHT", SCREEN_HEIGHT);
    options.addOption([]const u8, "BOARD_SALT", board_salt);

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");
    raylib_artifact.root_module.addIncludePath(b.path("src"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "raylib", .module = raylib },
            .{ .name = "build_options", .module = options.createModule() },
        },
    });

    const run_step = b.step("run", "Run the app");

    if (target.query.os_tag == .emscripten) {
        const emsdk = rlz.emsdk;
        const wasm = b.addLibrary(.{
            .name = "index",
            .root_module = exe_mod,
        });

        const install_dir: std.Build.InstallDir = .{ .custom = "web" };
        const emcc_flags = emsdk.emccDefaultFlags(b.allocator, .{ .optimize = optimize });
        const emcc_settings = emsdk.emccDefaultSettings(b.allocator, .{ .optimize = optimize });

        const emcc_step = emsdk.emccStep(b, raylib_artifact, wasm, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .install_dir = install_dir,
            .shell_file_path = b.path("src/shell/index.html"),
            .embed_paths = &.{
                .{ .src_path = "assets/board.png", .virtual_path = "board.png" },
                // .{ .src_path = "assets/dart.png", .virtual_path = "dart.png" },
                // .{ .src_path = "assets/dart_shadow.png", .virtual_path = "dart_shadow.png" },
                // .{ .src_path = "assets/name_arrow.png", .virtual_path = "name_arrow.png" },
                // .{ .src_path = "assets/background.png", .virtual_path = "background.png" },

                // .{ .src_path = "assets/concrete.wav", .virtual_path = "concrete.wav" },
                // .{ .src_path = "assets/dart.wav", .virtual_path = "dart.wav" },
            },
        });
        b.getInstallStep().dependOn(emcc_step);

        const npm_init_build_step = b.addSystemCommand(&.{ "npm", "--prefix", "client", "i" });

        const npm_client_js_build_step = b.addSystemCommand(&.{ "npm", "--prefix", "client", "run", "build" });

        const client_js_step = b.addInstallFile(b.path("client/dist/index.js"), "web/client.js");

        emcc_step.dependOn(&client_js_step.step);
        npm_client_js_build_step.step.dependOn(&npm_init_build_step.step);
        client_js_step.step.dependOn(&npm_client_js_build_step.step);

        const html_filename = try std.fmt.allocPrint(b.allocator, "index.html", .{});
        const emrun_step = emsdk.emrunStep(
            b,
            b.getInstallPath(install_dir, html_filename),
            &.{},
        );

        emrun_step.dependOn(emcc_step);
        run_step.dependOn(emrun_step);
    } else {
        const exe = b.addExecutable(.{
            .name = GAME_NAME,
            .root_module = exe_mod,
        });
        b.installArtifact(exe);

        const board_image_step = b.addInstallFile(b.path("assets/board.png"), "bin/board.png");
        b.getInstallStep().dependOn(&board_image_step.step);

        const dart_image_step = b.addInstallFile(b.path("assets/dart.png"), "bin/dart.png");
        b.getInstallStep().dependOn(&dart_image_step.step);

        const name_arrow_step = b.addInstallFile(b.path("assets/name_arrow.png"), "bin/name_arrow.png");
        b.getInstallStep().dependOn(&name_arrow_step.step);

        const darts_image_step = b.addInstallFile(b.path("assets/dart_shadow.png"), "bin/dart_shadow.png");
        b.getInstallStep().dependOn(&darts_image_step.step);

        const background_image_step = b.addInstallFile(b.path("assets/background.png"), "bin/background.png");
        b.getInstallStep().dependOn(&background_image_step.step);

        const concrete_step = b.addInstallFile(b.path("assets/concrete.wav"), "bin/concrete.wav");
        b.getInstallStep().dependOn(&concrete_step.step);

        const dart_step = b.addInstallFile(b.path("assets/dart.wav"), "bin/dart.wav");
        b.getInstallStep().dependOn(&dart_step.step);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.cwd = b.path("zig-out/bin");

        run_step.dependOn(&run_cmd.step);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args|
            run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
