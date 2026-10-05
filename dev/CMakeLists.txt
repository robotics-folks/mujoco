if(NOT TARGET mujoco::mujoco)
    message(FATAL_ERROR "Must have target 'mujoco::mujoco defined'")
endif()

if(NOT TARGET mujoco::filament)
    message(FATAL_ERROR "Must have target 'mujoco::filament' defined")
endif()
