# ~~~
# dev_setup_single_file_example(<filepath>
#       [INCLUDE_DIRECTORIES <include-dirs-list>...]
#       [TARGET_DEPENDENCIES <dependencies-list>...])
#
# Creates a simple target for a single-file example (given by `filepath`) that
# might depend on some given list of targets (given by `TARGET_DEPENDENCIES`)
# ~~~
macro(dev_setup_single_file_example filepath)
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
  dev_setup_example(
    TARGET ${target_name}
    SOURCES ${filepath}
    INCLUDE_DIRECTORIES ${sf_example_INCLUDE_DIRECTORIES}
    TARGET_DEPENDENCIES ${sf_example_TARGET_DEPENDENCIES})
endmacro()

# ~~~
# dev_setup_example(
#       [TARGET <target-name>]
#       [SOURCES <sources-list>...]
#       [INCLUDE_DIRECTORIES <include-dirs-list>...]
#       [TARGET_DEPENDENCIES <dependencies-list>...])
#
# Creates an executable target called `TARGET` with given `SOURCES`, and setup
# to use `TARGET_DEPENDENCIES` as targets to depend on
# ~~~
macro(dev_setup_example)
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
