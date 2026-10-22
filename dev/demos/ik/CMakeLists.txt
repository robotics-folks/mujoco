if(NOT TARGET mujoco::mujoco)
    message(FATAL_ERROR "Must have target 'mujoco::mujoco defined'")
endif()

if(NOT TARGET mujoco::filament)
    message(FATAL_ERROR "Must have target 'mujoco::filament' defined")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../cmake")

include(utils)

set(DEMOS_IK_COMPILE_OPTIONS "${AVX_COMPILE_OPTIONS}" "${EXTRA_COMPILE_OPTIONS}")
set(DEMOS_IK_LINK_OPTIONS "${EXTRA_LINK_OPTIONS}")

set(DEMOS_IK
  "${CMAKE_CURRENT_SOURCE_DIR}/diffik.cpp"
)

foreach(ex_filepath IN LISTS DEMOS_IK)
  dev_setup_single_file_example(
    ${ex_filepath}
    TARGET_DEPENDENCIES
        mujoco::mujoco
        mujoco::platform
        Threads::Threads
        CLI11::CLI11
        lodepng
  )
  get_filename_component(ex_target_name ${ex_filepath} NAME_WLE)

  target_compile_options(${ex_target_name}
    PUBLIC ${DEMOS_IK_COMPILE_OPTIONS} -Wno-implicit-fallthrough
  )
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(${ex_target_name}
        PRIVATE -Wno-gnu-anonymous-struct -Wno-nested-anon-types
    )
  endif()
  target_link_options(${ex_target_name} PRIVATE ${DEMOS_IK_LINK_OPTIONS})

  add_dependencies(${ex_target_name} mujoco_filament_assets)
endforeach()
