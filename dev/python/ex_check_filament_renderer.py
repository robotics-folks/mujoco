import argparse

import mujoco as mj
import mujoco.experimental.studio.window
import numpy as np
from mujoco import mjrf
from mujoco.rendering.filament import model_scene, renderer
from PIL import Image


def render(model: mj.MjModel, data: mj.MjData, width: int, height: int) -> np.ndarray:
  # create the rendering context
  ctx = mjrf.Context(mjrf.ContextConfig())

  # create a renderer
  r = renderer.Renderer(ctx)

  # add lights and renderables defined in the model to a scene in the renderer
  ms = model_scene.ModelScene(ctx, model, r.scene("scn"))

  # create the pixel buffer into which we'll render the image
  pixels = np.empty((height, width, 3), dtype=np.uint8)

  # associate the pixel buffer with a render target
  r.target("out", pixels)

  # update the lights and renderables with the current `data` state
  ms.update(data)

  # define the camera for the view we want to render
  vcam = mj.MjvCamera()
  vcam.type = mj.mjtCamera.mjCAMERA_FREE
  vcam.fixedcamid = -1

  mj.mjv_defaultFreeCamera(model, vcam)

  # define a view that connects the scene we want to render to an output target
  view = renderer.View(
    scene="scn",
    target="out",
    camera=mj.mjv_camera2GLCamera(model, data, vcam),
  )

  # render the scene; blocks until the render has completed writing to the render target
  r.render([view])

  # return the pixels
  return pixels


def main() -> int:
  cli = argparse.ArgumentParser()
  cli.add_argument("--model", type=str, required=True)

  args = cli.parse_args()

  model = mj.MjModel.from_xml_path(args.model)
  data = mj.MjData(model)

  mj.mj_resetData(model, data)
  mj.mj_forward(model, data)

  pixels = render(model, data, 1024, 768)
  pil_img = Image.fromarray(pixels)
  pil_img.save("test_render.png")

  return 0


if __name__ == "__main__":
  raise SystemExit(main())
