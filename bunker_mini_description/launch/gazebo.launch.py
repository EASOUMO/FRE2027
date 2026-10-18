import os
import subprocess

from ament_index_python.packages import get_package_share_path

from launch import LaunchDescription
from launch.actions import (AppendEnvironmentVariable, DeclareLaunchArgument,
                            IncludeLaunchDescription, LogInfo, OpaqueFunction)
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import Command, LaunchConfiguration, PythonExpression

from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def warn_if_gazebo_running(context):
    """A Gazebo left over from an earlier launch (for example one paused with
    Ctrl+Z instead of closed with Ctrl+C) shares this one's topics and
    services: the robot can be spawned into the old, invisible world and not
    appear in the new window. Say so instead of failing silently."""
    found = subprocess.run(['pgrep', '-a', '-f', 'gz sim'], capture_output=True, text=True).stdout
    pids = [line.split()[0] for line in found.splitlines() if 'pgrep' not in line]
    if not pids:
        return []
    return [LogInfo(msg=(
        '\n*** WARNING: another Gazebo is already running (pid ' + ', '.join(pids) + '). '
        'The robot may be spawned into that one and not appear here.\n'
        '*** Close it first: Ctrl+C in its terminal, or `kill %1` if it was paused with '
        'Ctrl+Z, or `pkill -9 -f "gz sim"` to stop every Gazebo.\n'))]


def generate_launch_description():
    pkg_share = get_package_share_path('bunker_mini_description')
    ros_gz_sim_share = get_package_share_path('ros_gz_sim')

    model_arg = DeclareLaunchArgument(
        name='model', default_value=str(pkg_share / 'urdf/bunker_mini.urdf'),
        description='Absolute path to the robot URDF/xacro file')
    world_arg = DeclareLaunchArgument(
        name='world', default_value=str(pkg_share / 'worlds/sensor_test.sdf'),
        description='Gazebo world; it must load the gz-sim-sensors-system plugin')
    headless_arg = DeclareLaunchArgument(
        name='headless', default_value='false', choices=['true', 'false'],
        description='Run the Gazebo server without its GUI')
    rviz_arg = DeclareLaunchArgument(
        name='rviz', default_value='false', choices=['true', 'false'],
        description='Start RViz')
    model_path_arg = DeclareLaunchArgument(
        name='model_path', default_value=str(pkg_share / 'worlds'),
        description='Directory searched for the model://... URIs of the world')
    pose_args = [
        DeclareLaunchArgument(name=name, default_value=default,
                              description=f'Spawn pose of the robot: {name}')
        for name, default in (('x', '0.0'), ('y', '0.0'), ('z', '0.30'), ('yaw', '0.0'))]

    robot_description = ParameterValue(
        Command(['xacro ', LaunchConfiguration('model')]), value_type=str)

    # Lets Gazebo resolve package://bunker_mini_description/... mesh URIs
    set_resource_path = AppendEnvironmentVariable(
        'GZ_SIM_RESOURCE_PATH', os.path.dirname(pkg_share))
    # Extra directories for model://... URIs (the maize field world's models)
    set_model_path = AppendEnvironmentVariable(
        'GZ_SIM_RESOURCE_PATH', LaunchConfiguration('model_path'))

    gazebo = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            str(ros_gz_sim_share / 'launch/gz_sim.launch.py')),
        launch_arguments={
            'gz_args': [
                PythonExpression(["'-r -s --headless-rendering ' if '",
                                  LaunchConfiguration('headless'),
                                  "' == 'true' else '-r '"]),
                LaunchConfiguration('world')],
            'on_exit_shutdown': 'true',
        }.items())

    robot_state_publisher_node = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        parameters=[{'robot_description': robot_description, 'use_sim_time': True}])

    spawn_node = Node(
        package='ros_gz_sim',
        executable='create',
        output='screen',
        arguments=['-name', 'bunker_mini', '-topic', 'robot_description',
                   '-x', LaunchConfiguration('x'), '-y', LaunchConfiguration('y'),
                   '-z', LaunchConfiguration('z'), '-Y', LaunchConfiguration('yaw')])

    bridge_node = Node(
        package='ros_gz_bridge',
        executable='parameter_bridge',
        output='screen',
        parameters=[{'config_file': str(pkg_share / 'config/gz_bridge.yaml'),
                     'use_sim_time': True}])

    rviz_node = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        output='screen',
        arguments=['-d', str(pkg_share / 'rviz/sensors.rviz')],
        parameters=[{'use_sim_time': True}],
        condition=IfCondition(LaunchConfiguration('rviz')))

    return LaunchDescription([
        OpaqueFunction(function=warn_if_gazebo_running),
        model_arg,
        world_arg,
        headless_arg,
        rviz_arg,
        model_path_arg,
        *pose_args,
        set_resource_path,
        set_model_path,
        gazebo,
        robot_state_publisher_node,
        spawn_node,
        bridge_node,
        rviz_node,
    ])
