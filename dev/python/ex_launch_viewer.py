import logging
import threading
from dataclasses import dataclass
from pathlib import Path

import mujoco as mj
import tyro
from mujoco.experimental.studio import (
    launch_native,
    launch_thread,
    messages,
    step_control,
    viewer_app,
    viewer_handle,
    viewer_protocol,
)
from rich.logging import RichHandler

# NOTE(wilbert): script adapted from issue 3579
# https://github.com/google-deepmind/mujoco/issues/3579


logging.basicConfig(
    level="DEBUG", format="%(message)s", datefmt="[%X]", handlers=[RichHandler()]
)


@dataclass
class Args:
    model: Path


def main() -> int:
    log = logging.getLogger("sample-viewer")
    log.info(f"MuJoCo version: {mj.__version__}")

    args = tyro.cli(Args)

    if not args.model.is_file():
        log.error(f"Given model @ {args.model} was not found")
        return 1

    model = mj.MjModel.from_xml_path(args.model.as_posix())
    data = mj.MjData(model)

    config = viewer_protocol.ViewerConfig()
    sim_plugins = [step_control.StepControl()]
    plugins = [viewer_app.ViewerApp()]

    viewer_endpoint, sim_endpoint = launch_thread.make_thread_endpoints()
    closed = threading.Event()
    handle = viewer_handle.ViewerHandle(
        sim_endpoint,
        sim_plugins=list(sim_plugins),
        is_alive_fn=lambda: not closed.is_set(),
        shutdown_fn=lambda: None,
    )

    def sim_loop():
        m, d = model, data
        handle.send_to_viewer(messages.ModelEvent(model=m, path=""))
        while not closed.is_set():
            m, d = handle.sync(m, d)

    thread = threading.Thread(target=sim_loop, daemon=True)
    thread.start()
    try:
        # Blocks. This is the call that has to be on the main thread.
        launch_native.run_native_viewer(config, viewer_endpoint, plugins=plugins)
    finally:
        closed.set()
        thread.join(timeout=5)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
