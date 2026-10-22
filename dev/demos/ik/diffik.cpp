#include <array>
#include <cstdio>
#include <memory>
#include <string>

#include <mujoco/mujoco.h>
#include <experimental/studio/hal/graphics_mode.h>
#include <experimental/studio/hal/window.h>

#include <CLI/CLI.hpp>

struct Args {
    std::string filepath = "";
    int window_width = 1024;
    int window_height = 768;
};

struct AppCtx {
    std::unique_ptr<mujoco::studio::Window> window = nullptr;
};

auto main(int argc, char **argv) -> int {
    CLI::App cli_app("Differential IK demo");
    argv = cli_app.ensure_utf8(argv);

    Args cli_args{};
    cli_app.add_option("--filepath", cli_args.filepath, "The path to the mjcf model to be loaded");
    cli_app.add_option("--window-width", cli_args.window_width, "The width of the window");
    cli_app.add_option("--window-height", cli_args.window_height, "The height of the window");

    CLI11_PARSE(cli_app, argc, argv);

    std::array<char, 1000> error;
    auto spec = mj_parseXML(cli_args.filepath.c_str(), NULL, error.data(), error.size());
    if (!spec) {
        mju_error("Couldn't load spec: %s", error.data());
        return 1;
    }

    auto model = mj_compile(spec, NULL);
    if (!model) {
        mju_error("Couldn't load model: %s", error.data());
        return 1;
    }

    auto data = mj_makeData(model);

    mj_resetData(model, data);
    mj_forward(model, data);

    // Initialize graphics stuff -------------------------
    AppCtx ctx;

    mujoco::studio::Window::Config window_cfg {
        .gfx_mode = mujoco::studio::GraphicsMode::FilamentVulkan
    };

    ctx.window = std::make_unique<mujoco::studio::Window>(
        "Differential IK demo",
        cli_args.window_width,
        cli_args.window_height,
        window_cfg
    );
    ctx.window->Resize(cli_args.window_width, cli_args.window_height);
    ctx.window->EnableWindowResizing();

    std::printf("Running demo ...\n");

    auto status = mujoco::studio::Window::Status::kRunning;
    while (status == mujoco::studio::Window::Status::kRunning) {
        status = ctx.window->NewFrame();

        ctx.window->EndFrame();
        ctx.window->Present();
    }

    // ---------------------------------------------------

    // TODO(wilbert): implement diffik here ...

    mj_deleteData(data);
    mj_deleteModel(model);

    std::printf("DONE :D\n");

    return 0;
}


