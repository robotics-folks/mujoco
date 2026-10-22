# ~~~
# wp_setup_single_file_example(<filepath>
#       [INCLUDE_DIRECTORIES <include-dirs-list>...]
#       [TARGET_DEPENDENCIES <dependencies-list>...])
#
# Creates a simple target for a single-file example (given by `filepath`) that
# might depend on some given list of targets (given by `TARGET_DEPENDENCIES`)
# ~~~
macro(wp_setup_single_file_example filepath)
  set(options)
  set(one_value_args)
  set(multi_value_args "INCLUDE_DIRECTORIES" "TARGET_DEPENDENCIES")
  cmake_parse_arguments(sf_example "${options}" "${one_value_args}"
                        "${multi_value_args}" ${ARGN})

  # -----------------------------------
  # Sanity check: make sure the targets we depend on exists
  if(DEFINED TARGET_DEPENDENCIES)
    foreach(target_dep ${sf_example_TARGET_DEPENDENCIES})
      if(NOT TARGET ${target_dep})
        message(WARNING "Tried configuring example [${filepath}] with dependency
          [${target_dep}], which doesn't exists")
        return()
      endif()
    endforeach()
  endif()

  # -----------------------------------
  # Create the target for our example
  get_filename_component(target_name ${filepath} NAME_WLE)
  wp_setup_example(
    TARGET ${target_name}
    SOURCES ${filepath}
    INCLUDE_DIRECTORIES ${sf_example_INCLUDE_DIRECTORIES}
    TARGET_DEPENDENCIES ${sf_example_TARGET_DEPENDENCIES})
endmacro()

# ~~~
# wp_setup_example(
#       [TARGET <target-name>]
#       [SOURCES <sources-list>...]
#       [INCLUDE_DIRECTORIES <include-dirs-list>...]
#       [TARGET_DEPENDENCIES <dependencies-list>...])
#
# Creates an executable target called `TARGET` with given `SOURCES`, and setup
# to use `TARGET_DEPENDENCIES` as targets to depend on
# ~~~
macro(wp_setup_example)
  set(options)
  set(one_value_args "TARGET")
  set(multi_value_args "SOURCES" "INCLUDE_DIRECTORIES" "TARGET_DEPENDENCIES")
  cmake_parse_arguments(example "${options}" "${one_value_args}"
                        "${multi_value_args}" ${ARGN})

  if(NOT DEFINED example_TARGET)
    message(WARNING "Argument `TARGET` is required for setting up an example")
    return()
  endif()

  if(NOT DEFINED example_SOURCES)
    message(WARNING "Argument `SOURCE is required for setting up an example")
    return()
  endif()

  add_executable(${example_TARGET})
  target_sources(${example_TARGET} PRIVATE ${example_SOURCES})
  if(DEFINED example_INCLUDE_DIRECTORIES)
    target_include_directories(${example_TARGET}
                               PRIVATE ${example_INCLUDE_DIRECTORIES})
  endif()
  if(DEFINED example_TARGET_DEPENDENCIES)
    target_link_libraries(${example_TARGET}
                          PRIVATE ${example_TARGET_DEPENDENCIES})
  endif()
endmacro()

if(NOT TARGET mujoco::mujoco)
    message(WARNING "Target mujoco::mujoco must be defined")
    return()
endif()

if(NOT TARGET mujoco::filament)
    message(WARNING "Target mujoco::filament must be defined")
    return()
endif()

set(MUJOCO_DEV_SAMPLE_COMPILE_OPTIONS "${AVX_COMPILE_OPTIONS}" "${EXTRA_COMPILE_OPTIONS}")
set(MUJOCO_DEV_SAMPLE_LINK_OPTIONS "${EXTRA_LINK_OPTIONS}")

if(MUJOCO_HARDEN)
  if(WIN32)
    set(MUJOCO_SAMPLE_LINK_OPTIONS "${MUJOCO_SAMPLE_LINK_OPTIONS}" -Wl,/DYNAMICBASE)
  else()
    set(MUJOCO_SAMPLE_COMPILE_OPTIONS "${MUJOCO_SAMPLE_COMPILE_OPTIONS}" -fPIE)
    if(APPLE)
      set(MUJOCO_SAMPLE_LINK_OPTIONS "${MUJOCO_SAMPLE_LINK_OPTIONS}" -Wl,-pie)
    else()
      set(MUJOCO_SAMPLE_LINK_OPTIONS "${MUJOCO_SAMPLE_LINK_OPTIONS}" -pie)
    endif()
  endif()
endif()

set(TESTS_DEV_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/test_render_filament.cc
)

foreach(ex_filepath IN LISTS TESTS_DEV_LIST)
  wp_setup_single_file_example(${ex_filepath} TARGET_DEPENDENCIES mujoco::mujoco mujoco::platform CLI11::CLI11 Threads::Threads lodepng)
  get_filename_component(ex_target_name ${ex_filepath} NAME_WLE)
  target_compile_options(${ex_target_name} PUBLIC ${MUJOCO_DEV_SAMPLE_COMPILE_OPTIONS} -Wno-implicit-fallthrough)
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        target_compile_options(${ex_target_name} PRIVATE -Wno-gnu-anonymous-struct -Wno-nested-anon-types)
  endif()
  target_link_options(${ex_target_name} PRIVATE ${MUJOCO_DEV_SAMPLE_LINK_OPTIONS})
endforeach()

if(TARGET test_render_filament)
  add_dependencies(test_render_filament mujoco_filament_assets)
  # add_custom_command(
  #   TARGET test_render_filament POST_BUILD
  #   COMMAND ${CMAKE_COMMAND} -E copy_directory
  #     ${CMAKE_BINARY_DIR}/src/render/filament/assets
  #     $<TARGET_FILE_DIR:test_render_filament>/assets
  #   COMMENT "Deploying Filament assets for render sample")
endif()


