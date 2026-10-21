import time
from dataclasses import dataclass
from pathlib import Path

import mujoco as mj
import tyro
from mujoco.experimental.studio import launch_passive, messages, viewer_protocol


@dataclass
class Args:
  model: Path


def main() -> int:
  args = tyro.cli(Args)

  if not args.model.is_file():
    print(f"[ERROR]: Given model @ {args.model} was not found")
    return 1

  model = mj.MjModel.from_xml_path(args.model.as_posix())
  data = mj.MjData(model)

  handle = launch_passive.run(
    viewer_protocol.ViewerConfig(title="studio repro", width=900, height=600)
  )
  handle.send_to_viewer(messages.ModelEvent(model=model, path=args.model.as_posix()))
  print("launch_passive returned, is_running:", handle.is_running(), flush=True)

  for _ in range(200):
    model, data = handle.sync(model, data)
    time.sleep(0.02)

  print("finished normally", flush=True)

  return 0


if __name__ == "__main__":
  raise SystemExit(main())
