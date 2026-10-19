"""Open the field virtual_maize_field generated last, with a robot in it.

    ros2 run virtual_maize_field generate_world tomato_field
    ros2 launch hunter_se_description generated_field.launch.py robot:=ranger_mini

The generator's own simulation.launch.py opens the world without a robot,
and its robot_spawner.launch.py needs to be told which model to spawn. This
does both for the robots of this workspace: it takes the world and the start
pose the generator wrote to ~/.ros/virtual_maize_field/, adds the sensors
plugin the robots' lidar and camera need (the generated world has none) and
starts <robot>_description's gazebo.launch.py with them.

Unlike maize_field/tomato_field/lettuce_field.launch.py, which open fixed
copies kept in this package, this follows whatever was generated last.
"""

import os
import re
from pathlib import Path

from ament_index_python.packages import PackageNotFoundError, get_package_share_path

from launch import LaunchDescription
from launch.actions import (AppendEnvironmentVariable, DeclareLaunchArgument,
                            IncludeLaunchDescription, LogInfo, OpaqueFunction)
from launch.launch_description_sources import PythonLaunchDescriptionSource

# robot -> height of base_link above the ground at spawn (m)
ROBOTS = {'hunter_se': 0.35, 'bunker_mini': 0.35, 'ranger_mini': 0.20}

SENSORS_PLUGIN = '''
    <!-- Added by generated_field.launch.py: needed by the robots' lidar and camera -->
    <plugin
      filename="gz-sim-sensors-system"
      name="gz::sim::systems::Sensors">
      <render_engine>ogre2</render_engine>
    </plugin>
'''


def world_with_sensors(field_dir: Path) -> Path:
    """Copy of generated.world with the sensors plugin, next to the original."""
    world = (field_dir / 'generated.world').read_text()
    if 'gz-sim-sensors-system' not in world:
        scene_broadcaster = re.search(
            r'<plugin\s+filename="gz-sim-scene-broadcaster-system".*?</plugin>', world, re.S)
        if scene_broadcaster is None:
            raise RuntimeError(f'no scene broadcaster plugin in {field_dir / "generated.world"}: '
                               'not a world written by virtual_maize_field?')
        world = world[:scene_broadcaster.end()] + SENSORS_PLUGIN + world[scene_broadcaster.end():]
    patched = field_dir / 'generated_with_sensors.world'
    patched.write_text(world)
    return patched


def start_pose(field_dir: Path) -> dict:
    """x, y, z, yaw the generator put into robot_spawner.launch.py."""
    spawner = (field_dir / 'robot_spawner.launch.py').read_text()
    pose = {}
    for name, key in (('x', 'x'), ('y', 'y'), ('z', 'z'), ('yaw', 'Y')):
        match = re.search(rf'LaunchConfiguration\("{key}", default="([-+0-9.eE]+)"\)', spawner)
        if match is None:
            raise RuntimeError(f'no default for {key} in {field_dir / "robot_spawner.launch.py"}')
        pose[name] = float(match.group(1))
    return pose


def launch_setup(context):
    cfg = context.launch_configurations
    robot = cfg['robot']
    field_dir = Path(cfg['field_dir']).expanduser()
    if not (field_dir / 'generated.world').is_file():
        raise RuntimeError(f'{field_dir / "generated.world"} not found: generate a field first '
                           '(ros2 run virtual_maize_field generate_world)')

    field_models = cfg['field_models']
    if not field_models:
        try:
            field_models = str(get_package_share_path('virtual_maize_field') / 'models')
        except PackageNotFoundError:
            raise RuntimeError(
                'virtual_maize_field is not in this environment, so the plants and ground textures '
                'of the generated world cannot be found. Source the workspace it was built in '
                '(source ~/Documents/virtual_field_ws/install/setup.bash) or pass field_models:=<its models folder>')

    pose = start_pose(field_dir)
    # The generator's z is 0.35 m above the field's ground level, for a robot
    # of unknown size; put this robot's base_link at its own height instead.
    ground = pose['z'] - 0.35
    for name in ('x', 'y', 'yaw'):
        if cfg[name]:
            pose[name] = float(cfg[name])
    z = float(cfg['z']) if cfg['z'] else ground + ROBOTS[robot]

    world = world_with_sensors(field_dir)
    robot_share = get_package_share_path(f'{robot}_description')
    seed = re.search(r'<!-- Seed: (\d+) -->', world.read_text())
    crops = sorted(set(re.findall(r'<uri>model://([a-z_]+?)_\d+</uri>', world.read_text())))

    return [
        LogInfo(msg=f'generated field: {world} (seed {seed.group(1) if seed else "?"}, '
                    f'crop {", ".join(crops) or "?"}); {robot} at x={pose["x"]:.2f} y={pose["y"]:.2f} '
                    f'z={z:.2f} yaw={pose["yaw"]:.2f}'),
        # the generated world's model://maize_01, model://materials/... URIs
        AppendEnvironmentVariable('GZ_SIM_RESOURCE_PATH', field_models),
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(str(robot_share / 'launch/gazebo.launch.py')),
            launch_arguments={
                'world': str(world),
                'x': str(pose['x']), 'y': str(pose['y']), 'z': str(z), 'yaw': str(pose['yaw']),
                'headless': cfg['headless'],
                'rviz': cfg['rviz'],
                'visualization': cfg['visualization'],
            }.items()),
    ]


def generate_launch_description():
    ros_home = os.environ.get('ROS_HOME', os.path.join(os.path.expanduser('~'), '.ros'))
    return LaunchDescription([
        DeclareLaunchArgument(
            name='robot', default_value='ranger_mini', choices=list(ROBOTS),
            description='Robot to put into the generated field'),
        DeclareLaunchArgument(
            name='field_dir', default_value=os.path.join(ros_home, 'virtual_maize_field'),
            description='Folder virtual_maize_field generated into (generated.world, '
                        'robot_spawner.launch.py, heightmap)'),
        DeclareLaunchArgument(
            name='field_models', default_value='',
            description='Folder with the plant and ground models of the generated world '
                        '(default: the models of the sourced virtual_maize_field package)'),
        DeclareLaunchArgument(
            name='headless', default_value='false', choices=['true', 'false'],
            description='Run the Gazebo server without its GUI'),
        DeclareLaunchArgument(
            name='rviz', default_value='false', choices=['true', 'false'],
            description='Start RViz'),
        DeclareLaunchArgument(
            name='visualization', default_value='false', choices=['true', 'false'],
            description='Start RViz (same as rviz:=true)'),
        *[DeclareLaunchArgument(name=name, default_value='',
                                description=f'Spawn pose: {name} (default: the start pose the generator chose)')
          for name in ('x', 'y', 'z', 'yaw')],
        OpaqueFunction(function=launch_setup),
    ])
