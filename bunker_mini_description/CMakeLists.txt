cmake_minimum_required(VERSION 3.8)
project(bunker_mini_description)

find_package(ament_cmake REQUIRED)

install(
  DIRECTORY config launch meshes rviz urdf worlds
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
