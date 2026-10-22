message(STATUS "Configuring C++ dev demos")

FetchContent_Declare(
  cli11
  GIT_REPOSITORY https://github.com/CLIUtils/CLI11.git
  GIT_TAG 457839d482455e746faabc07e2e6fa4c30f2d553
)
FetchContent_MakeAvailable(cli11)

add_subdirectory(cpp)
add_subdirectory(demos/ik)
