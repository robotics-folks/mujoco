# Copyright 2026 DeepMind Technologies Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Native desktop viewer launcher."""

import sys
import threading
from collections.abc import Callable, Iterable
from typing import Any

import mujoco
from mujoco.experimental.studio import (
  endpoints,
  launch_thread,
  messages,
  plugin,
  viewer_handle,
  viewer_protocol,
)


def _run_viewer_on_main_thread(
  config: viewer_protocol.ViewerConfig,
  sim_loop: Callable[[viewer_handle.ViewerHandle], None],
  *,
  viewer_plugins: list[Any] | None = None,
  sim_plugins: list[Any] | None = None,
) -> None:
  viewer_endpoint, sim_endpoint = launch_thread.make_thread_endpoints()

  stop = threading.Event()
  handle = viewer_handle.ViewerHandle(
    sim_endpoint,
    sim_plugins=sim_plugins,
    is_alive_fn=lambda: not stop.is_set(),
    shutdown_fn=lambda _timeout: None,
  )

  sim_error: Exception | None = None

  def run_sim() -> None:
    nonlocal handle, sim_error
    try:
      with handle:
        sim_loop(handle)
    except Exception as e:
      sim_error = e

  sim_thread = threading.Thread(target=run_sim, daemon=True)
  sim_thread.start()

  try:
    run_native_viewer(config, viewer_endpoint, plugins=viewer_plugins)
  finally:
    stop.set()
    sim_thread.join(timeout=5.0)

  if sim_error is not None:
    raise sim_error


def run_native_viewer(
  config: viewer_protocol.ViewerConfig,
  endpoint: endpoints.ViewerEndpoint,
  plugins: list[Any] | None = None,
) -> None:
  """Creates a NativeViewer and runs the viewer loop.

  Args:
    config: Configuration specifying the viewer window settings.
    endpoint: Endpoint for communicating with the simulation side.
    plugins: Optional list of viewer-side plugin instances.
  """
  from mujoco.experimental.studio import native_viewer  # pylint: disable=g-import-not-at-top

  viewer = native_viewer.NativeViewer(config, endpoint, plugins=plugins)
  viewer_protocol.run_viewer_loop(viewer)


def launch(
  config: viewer_protocol.ViewerConfig | None = None,
  *,
  plugins: Iterable[plugin.Plugin] | None = None,
) -> viewer_handle.ViewerHandle:
  """Launches the NativeViewer in a daemon thread without blocking.

  Args:
    config: Optional ViewerConfig (defaults to standard ViewerConfig()).
    plugins: Optional viewer and sim plugins.

  Returns:
    A ViewerHandle for interacting with the viewer.
  """
  if config is None:
    config = viewer_protocol.ViewerConfig()
  viewer_plugins, sim_plugins = plugin.split_plugins(plugins)

  def target(endpoint: endpoints.ViewerEndpoint) -> None:
    run_native_viewer(config, endpoint, plugins=viewer_plugins)

  return launch_thread.launch_thread(target, sim_plugins=sim_plugins)


def run(
  config: viewer_protocol.ViewerConfig | None = None,
  *,
  model: mujoco.MjModel | None = None,
  data: mujoco.MjData | None = None,
  model_path: str | None = None,
  plugins: Iterable[plugin.Plugin] | None = None,
) -> None:
  """Launches the NativeViewer and runs the blocking simulation sync loop.

  Args:
    config: Optional ViewerConfig (defaults to standard ViewerConfig()).
    model: In-memory model to publish instead.
    data: The data for ``model``; a fresh one is created when None.
    model_path: Model file to load.
    plugins: Optional viewer and sim plugins.

  Raises:
    ValueError: If both ``model`` and ``model_path`` are given.
  """
  if model is not None and model_path:
    raise ValueError("Pass either model_path or model, not both.")

  match sys.platform:
    case "darwin":

      def sim_loop(handle: viewer_handle.ViewerHandle) -> None:
        nonlocal model, model_path
        if model is not None:
          handle.set_model(model)
        elif model_path is not None:
          handle.dispatch(messages.LoadModelEvent(path=model_path))
        viewer_handle.run_sim_loop(handle)

      viewer_plugins, sim_plugins = plugin.split_plugins(plugins)
      _run_viewer_on_main_thread(
        config, sim_loop, viewer_plugins=viewer_plugins, sim_plugins=sim_plugins
      )
    case _:
      with launch(config, plugins=plugins) as handle:
        if model is not None:
          handle.set_model(model, data=data)
        elif model_path:
          handle.dispatch(messages.LoadModelEvent(path=model_path))
          viewer_handle.run_sim_loop(handle)
