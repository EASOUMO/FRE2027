from ament_index_python.packages import get_package_share_path

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition, UnlessCondition
from launch.substitutions import Command, LaunchConfiguration

from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def generate_launch_description():
    pkg_share = get_package_share_path('ranger_mini_description')

    model_arg = DeclareLaunchArgument(
        name='model', default_value=str(pkg_share / 'urdf/ranger_mini.urdf'),
        description='Absolute path to the robot URDF/xacro file')
    gui_arg = DeclareLaunchArgument(
        name='gui', default_value='true', choices=['true', 'false'],
        description='Use joint_state_publisher_gui instead of joint_state_publisher')
    rviz_arg = DeclareLaunchArgument(
        name='rviz', default_value='true', choices=['true', 'false'],
        description='Start RViz')
    rviz_config_arg = DeclareLaunchArgument(
        name='rvizconfig', default_value=str(pkg_share / 'rviz/display.rviz'),
        description='Absolute path to the RViz config file')
    use_sim_time_arg = DeclareLaunchArgument(
        name='use_sim_time', default_value='false', choices=['true', 'false'],
        description='Use simulation clock')

    robot_description = ParameterValue(
        Command(['xacro ', LaunchConfiguration('model')]), value_type=str)

    robot_state_publisher_node = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        parameters=[{'robot_description': robot_description,
                     'use_sim_time': LaunchConfiguration('use_sim_time')}])

    joint_state_publisher_node = Node(
        package='joint_state_publisher',
        executable='joint_state_publisher',
        condition=UnlessCondition(LaunchConfiguration('gui')))

    joint_state_publisher_gui_node = Node(
        package='joint_state_publisher_gui',
        executable='joint_state_publisher_gui',
        condition=IfCondition(LaunchConfiguration('gui')))

    rviz_node = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        output='screen',
        arguments=['-d', LaunchConfiguration('rvizconfig')],
        condition=IfCondition(LaunchConfiguration('rviz')))

    return LaunchDescription([
        model_arg,
        gui_arg,
        rviz_arg,
        rviz_config_arg,
        use_sim_time_arg,
        joint_state_publisher_node,
        joint_state_publisher_gui_node,
        robot_state_publisher_node,
        rviz_node,
    ])
