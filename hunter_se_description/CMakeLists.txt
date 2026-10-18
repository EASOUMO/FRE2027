cmake_minimum_required(VERSION 3.8)
project(hunter_se_description)

find_package(ament_cmake REQUIRED)

install(
  DIRECTORY config launch meshes models rviz urdf worlds
  DESTINATION share/${PROJECT_NAME}
)

ament_package()
