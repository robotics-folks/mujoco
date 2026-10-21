import time
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import mujoco as mj
import tyro
from mujoco.experimental.studio import (
  launch_passive,
  messages,
  step_control,
  viewer_app,
  viewer_protocol,
)


@dataclass
class Args:
  model: Path
  gfx: Literal["opengl", "vulkan", "web"] = "opengl"
  width: int = 1024
  height: int = 768


def main() -> int:
  args = tyro.cli(Args)

  if not args.model.is_file():
    print(f"[ERROR]: Given model @ {args.model} was not found")
    return 1

  model = mj.MjModel.from_xml_path(args.model.as_posix())
  data = mj.MjData(model)

  config = viewer_protocol.ViewerConfig(
    title="Studio passive example",
    width=args.width,
    height=args.height,
    gfx=args.gfx,
  )

  plugins = [
    step_control.StepControl(),
    viewer_app.ViewerApp(),
  ]
  launch_passive.run(config, model=model, data=data, plugins=plugins)

  return 0


if __name__ == "__main__":
  raise SystemExit(main())
