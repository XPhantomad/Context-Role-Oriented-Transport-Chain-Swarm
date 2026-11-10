find_package(argos3_ros2_bridge REQUIRED)

add_library(argos_ros_bridge SHARED argos_ros_bridge.h argos_ros_bridge.cpp)

target_include_directories(argos_ros_bridge PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${ARGOS_INCLUDE_DIRS}
)

target_link_libraries(argos_ros_bridge PUBLIC
  ${cpp_typesupport_target}
  rclcpp::rclcpp
  ${geometry_msgs_TARGETS}
  ${std_msgs_TARGETS}
  /usr/lib/argos3/libargos3plugin_simulator_footbot.so
  /usr/lib/argos3/libargos3plugin_simulator_genericrobot.so
  /usr/lib/argos3/libargos3core_simulator.so
)
  

install(
  TARGETS argos_ros_bridge
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION lib
)
