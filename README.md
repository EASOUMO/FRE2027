# FRE2027

Simulation of three AgileX field robots for the Field Robot Event 2027, built
for **ROS 2 Jazzy** and **Gazebo Harmonic** (`gz sim`). Each robot carries the
same sensor mount (an RPLidar C1 lidar, a RealSense-style RGB-D camera, and an
IMU), so code written against one robot's topics works on the others.

There are three crop fields (maize, tomato, lettuce) made with
[`virtual_maize_field`](https://github.com/FieldRobotEvent/virtual_maize_field),
plus a small flat world for checking the sensors. Any robot can be started in
any world with a single launch command.

---

## Contents

1. [Packages](#1-packages)
2. [The robots](#2-the-robots)
3. [The worlds](#3-the-worlds)
4. [Requirements](#4-requirements)
5. [Install and build](#5-install-and-build)
6. [Quick start](#6-quick-start)
7. [Launch files and arguments](#7-launch-files-and-arguments)
8. [Driving the robots (teleoperation)](#8-driving-the-robots-teleoperation)
9. [Topics, frames and sensors](#9-topics-frames-and-sensors)
10. [Using a newly generated field](#10-using-a-newly-generated-field)
11. [Troubleshooting](#11-troubleshooting)
12. [Repository layout](#12-repository-layout)

---

## 1. Packages

| Package | What it contains |
|---|---|
| `hunter_se_description` | The **Hunter SE** robot, **plus the three field worlds and all their plant and terrain models**. The other two packages load their fields from here, so it is always required. |
| `bunker_mini_description` | The **Bunker Mini** robot: URDF, meshes, Gazebo bridge config, RViz configs and launch files. |
| `ranger_mini_description` | The **Ranger Mini** robot: the same files, plus `four_ws_controller.py`, which turns `cmd_vel` into steering angles and wheel speeds. |

All three are `ament_cmake` packages that install their files only; nothing is
compiled.

## 2. The robots

| | Hunter SE | Bunker Mini | Ranger Mini |
|---|---|---|---|
| Drive type | Ackermann (car-like): rear-wheel drive, front steering | Tracked, skid-steer | Four-wheel independent steering |
| What executes `cmd_vel` | Gazebo `AckermannSteering` plugin | Gazebo `DiffDrive` plugin | `four_ws_controller.py` node → Gazebo joint controllers |
| Can turn on the spot | no (steering limit 0.52 rad, 30°) | yes | yes |
| Can move sideways (`linear.y`) | no | no | yes (crab mode) |
| Speed limit in the model | 4.8 m/s | 1.5 m/s, 2.0 rad/s | 1.5 m/s at any wheel |
| Gazebo model name | `hunter_se` | `bunker_mini` | `ranger_mini` |
| URDF | `urdf/hunter_se_description.urdf` | `urdf/bunker_mini.urdf` | `urdf/ranger_mini.urdf` |

Modelling notes:

- **Bunker Mini:** the body is a single rigid mesh, so the tracks are drawn
  but don't move. Six hidden wheels (three per side) stand in for the tracks.
  The middle pair grips fully and the end pairs grip less, so the robot
  pivots about its centre the way a tracked robot does.
- **Ranger Mini:** the visual is one whole-robot mesh as well. The four
  steering modules and wheels underneath are hidden links that carry the
  physics.
- **Sensor mount:** the same mount (Onshape export) is fixed to the top
  deck of every robot. It holds the lidar, with the camera on the front
  facing forward.

## 3. The worlds

| World file | Rows | Notes |
|---|---|---|
| `sensor_test.sdf` | none | Flat ground with a red box, a green cylinder and a blue box, for checking the lidar and camera. Each robot package has its own copy. |
| `maize_field.sdf` | 6 rows, 0.75 m apart, about 16 m long | Curved rows with gaps. The lanes are narrow: the Bunker Mini has about 9 cm of room on each side. |
| `tomato_field.sdf` | 6 rows, 1.2 m apart, about 18 m long | Staked plants every 0.5 m. Seed 4676. |
| `lettuce_field.sdf` | 6 rows, 1.0 m apart | A lettuce head every 0.3 m. **The heads are only 0.16 m tall, so the lidar (0.4–0.5 m up) can't see them**; this field is meant for camera-based navigation. Seed 3658. |

The field worlds are in `hunter_se_description/worlds/`. Their plant,
heightmap and material models are in `hunter_se_description/models/`. Every
world loads the `gz-sim-sensors-system` plugin, which the lidar and camera
need in order to publish.

Each robot spawns at the field's start pose: in the headland, facing down the
first row.

| Field | x | y | yaw |
|---|---|---|---|
| maize | 0.8094 | -8.5386 | 1.5658 |
| tomato | -1.4596 | -11.2231 | 1.6078 |
| lettuce | 1.1736 | -8.8232 | 1.6164 |

## 4. Requirements

- Ubuntu 24.04
- ROS 2 Jazzy (`ros-jazzy-desktop`)
- Gazebo Harmonic plus the ROS–Gazebo bridge, which come with `ros-jazzy-ros-gz`

Install the ROS packages these launch files use:

```bash
sudo apt update
sudo apt install \
  ros-jazzy-ros-gz \
  ros-jazzy-robot-state-publisher \
  ros-jazzy-joint-state-publisher \
  ros-jazzy-joint-state-publisher-gui \
  ros-jazzy-xacro \
  ros-jazzy-rviz2 \
  ros-jazzy-teleop-twist-keyboard
```

Alternatively, once the repo is cloned (next section), `rosdep` reads the
`package.xml` files and installs whatever is missing:

```bash
cd ~/fre_ws
rosdep install --from-paths src --ignore-src -y
```

## 5. Install and build

The repository root holds the three packages, so clone it into the `src/`
folder of a colcon workspace:

```bash
mkdir -p ~/fre_ws/src
cd ~/fre_ws/src
git clone git@github.com:EASOUMO/FRE2027.git

cd ~/fre_ws
source /opt/ros/jazzy/setup.bash
colcon build --symlink-install
source install/setup.bash
```

`--symlink-install` links the installed files to the source tree, so changes
to the URDFs, worlds and launch files take effect without rebuilding. A new
file still needs a rebuild.

Run `source ~/fre_ws/install/setup.bash` in **every new terminal**, or add
it to `~/.bashrc`:

```bash
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
echo "source ~/fre_ws/install/setup.bash" >> ~/.bashrc
```

> If the build fails with `ModuleNotFoundError: No module named 'catkin_pkg'`,
> see [Troubleshooting](#11-troubleshooting).

## 6. Quick start

Start a robot in a field, with the Gazebo window:

```bash
ros2 launch bunker_mini_description maize_field.launch.py
```

Then, in a second terminal, drive it from the keyboard (`i` forward, `j`/`l`
turn, `k` stop; see [section 8](#8-driving-the-robots-teleoperation)):

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

Every combination of robot and world:

```bash
# <robot> is hunter_se, bunker_mini or ranger_mini
ros2 launch <robot>_description gazebo.launch.py          # flat sensor_test world
ros2 launch <robot>_description maize_field.launch.py
ros2 launch <robot>_description tomato_field.launch.py
ros2 launch <robot>_description lettuce_field.launch.py
```

Useful variations:

```bash
# Also open RViz with the lidar, camera images and TF
ros2 launch ranger_mini_description tomato_field.launch.py rviz:=true

# No Gazebo window (faster; good for long runs, recording data or SSH sessions)
ros2 launch hunter_se_description maize_field.launch.py headless:=true

# Spawn somewhere else
ros2 launch bunker_mini_description maize_field.launch.py x:=1.5 y:=-8.5 yaw:=1.57

# Only view the robot model in RViz (no simulation), with sliders for the joints
ros2 launch ranger_mini_description description.launch.py
```

Close a simulation with **Ctrl+C** in the terminal where you launched it.
Don't use Ctrl+Z: it pauses Gazebo instead of stopping it, and the paused
Gazebo interferes with the next launch (see
[Troubleshooting](#11-troubleshooting)).

## 7. Launch files and arguments

Every robot package has the same five launch files.

### `gazebo.launch.py`: simulation in any world

This file does the work; the field launch files below call it. It:

1. adds the package share directory and `model_path` to `GZ_SIM_RESOURCE_PATH`,
   so Gazebo can find the `package://` meshes and the `model://` plants,
2. starts Gazebo with `world`, already running (`-r`),
3. starts `robot_state_publisher` with the URDF (run through `xacro`),
4. spawns the robot from the `robot_description` topic,
5. starts `ros_gz_bridge` with `config/gz_bridge.yaml`,
6. on the Ranger Mini only, starts `four_ws_controller.py`,
7. if `rviz:=true`, opens RViz with `rviz/sensors.rviz`.

It also warns you if another Gazebo is already running.

| Argument | Default | Meaning |
|---|---|---|
| `world` | `<pkg>/worlds/sensor_test.sdf` | SDF world to load; it must contain the `gz-sim-sensors-system` plugin |
| `model` | `<pkg>/urdf/<robot>.urdf` | Robot URDF or xacro file |
| `model_path` | `<pkg>/worlds` | Extra directory searched for `model://` URIs (Bunker and Ranger only; the Hunter SE always searches its own `models/`) |
| `headless` | `false` | `true` runs the Gazebo server only, with headless rendering (sensors still work) |
| `rviz` | `false` | `true` opens RViz |
| `x`, `y`, `z`, `yaw` | `0`, `0`, height above ground, `0` | Spawn pose, in metres and radians |

Every node is started with `use_sim_time: true`.

### `maize_field.launch.py`, `tomato_field.launch.py`, `lettuce_field.launch.py`

These call `gazebo.launch.py` with the field's world from
`hunter_se_description/worlds/`, set `model_path` to
`hunter_se_description/models/`, and set the spawn pose to the field's
start pose (see [the worlds](#3-the-worlds)).

They accept `world`, `headless`, `rviz`, `x`, `y`, `z` and `yaw`, and pass
them on. The spawn height `z` is 0.65 m for the Hunter SE and Bunker Mini
and 0.50 m for the Ranger Mini: the robot is dropped a little onto the uneven
ground.

### `description.launch.py`: the model only, no simulation

Starts `robot_state_publisher`, a joint state publisher and RViz, for checking the URDF, frames and meshes.

| Argument | Default | Meaning |
|---|---|---|
| `model` | `<pkg>/urdf/<robot>.urdf` | Robot URDF or xacro file |
| `gui` | `true` | `true` shows joint sliders (`joint_state_publisher_gui`); `false` uses the plain `joint_state_publisher` |
| `rviz` | `true` | Start RViz |
| `rvizconfig` | `<pkg>/rviz/display.rviz` (`rviz.rviz` for the Hunter SE) | RViz config file |
| `use_sim_time` | `false` | Use the simulation clock |

Run `ros2 launch <pkg> <file> --show-args` to list any launch file's
arguments.

`hunter_se_description` also has a sixth launch file, `generated_field.launch.py`
(see [section 10](#10-using-a-newly-generated-field)).

## 8. Driving the robots (teleoperation)

All three robots take `geometry_msgs/msg/Twist` on **`/cmd_vel`**:
`linear.x` is the forward speed in m/s, `linear.y` the sideways speed (Ranger
Mini only) and `angular.z` the yaw rate in rad/s. Drive them with the
standard ROS keyboard teleop.

### Keyboard teleop

Start a simulation in one terminal, then run this in a **second terminal**:

```bash
source ~/fre_ws/install/setup.bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

Keep that terminal focused while driving: it reads keys only when it is the
active window. If `teleop_twist_keyboard` isn't installed, install it with
`sudo apt install ros-jazzy-teleop-twist-keyboard`.

**Press a key once, not repeatedly.** Each key press sends one command,
and the robot keeps doing it until another key changes it. Press **`k`**
(or any key that isn't listed below) to stop.

```
   u    i    o          i  forward             ,  backward
   j    k    l          j  turn left on spot   l  turn right on spot
   m    ,    .          u  forward + left      o  forward + right
                        m  backward + left     .  backward + right
                        k  STOP
```

Sideways (strafing), **Ranger Mini only**: hold **Shift**.

```
   U    I    O          J  left               L  right
   J    K    L          U / O  forward + left / right
   M    <    >          M / >  backward + left / right
```

Speed keys. The defaults are 0.5 m/s and 1.0 rad/s; each press changes
them by 10 %.

| Key | Effect |
|---|---|
| `q` / `z` | both speeds up / down |
| `w` / `x` | linear speed only, up / down |
| `e` / `c` | turning speed only, up / down |

To start at other speeds:

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args -p speed:=0.3 -p turn:=0.6
```

Quit with **Ctrl+C**: the teleop sends a final stop command as it exits.
If its terminal is closed or killed instead, no stop is sent and the robot
keeps its last command. Stop it with `ros2 topic pub --once /cmd_vel
geometry_msgs/msg/Twist "{}"`.

### What each key does on each robot

The keys are the same for all three robots; the drive type decides what
the robot can do with them.

| Keys | Bunker Mini (skid-steer) | Hunter SE (car-like) | Ranger Mini (4-wheel steering) |
|---|---|---|---|
| `i` `,` forward / back | yes | yes | yes |
| `u` `o` `m` `.` drive while turning | yes | yes | yes, front and rear wheels counter-steer |
| `j` `l` spin on the spot | yes | **no**: nothing happens, because a car can't turn while standing still. Use `u` / `o`. | yes |
| Shift + `J` `L` sideways | **no** | **no** | yes (crab mode) |
| top speed in the model | 1.5 m/s, 2.0 rad/s | 4.8 m/s, steering limit 30° | 1.5 m/s at any wheel |

The Hunter SE's tightest turn is limited by its steering, at about
1.0 rad/s of turning per 1 m/s of speed. A larger `turn` value just
holds the wheels at full lock.

### From the shell or your own code

```bash
# forward at 0.3 m/s while turning slowly left, until Ctrl+C
ros2 topic pub -r 10 /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.3}, angular: {z: 0.2}}"

# stop
ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{}"
```

All three robots **keep the last `cmd_vel` until a new one arrives**:
the Bunker Mini's `DiffDrive` and the Hunter SE's `AckermannSteering`
Gazebo plugins work this way, and the Ranger Mini's controller is set to
match. A node that drives the robot should therefore publish a zero
`Twist` when it stops or exits.

### Ranger Mini controller

`four_ws_controller.py` (started by the Ranger's launch files) turns
`cmd_vel` into a steering angle and a wheel speed for each of the four
wheels. Each wheel is steered along the velocity it needs, and no wheel
steers more than 90°: past that it turns the short way and drives
backwards. Parameters:

| Parameter | Default | Meaning |
|---|---|---|
| `cmd_vel_timeout` | `0.0` | Seconds without `cmd_vel` before the wheels stop. `0` keeps the last command, like the other two robots. Set it, for example to 0.5, for a safety stop when your controller dies; with `teleop_twist_keyboard` that would stop the robot half a second after every key press. |
| `wheel_radius` | `0.08` | m |
| `max_speed` | `1.5` | m/s at any wheel; faster commands are scaled down together |

It publishes the eight joint commands on `/steering/{fl,fr,rl,rr}` (angle in
rad) and `/wheel/{fl,fr,rl,rr}` (speed in rad/s) as `std_msgs/msg/Float64`.
You can publish to these directly to test a single wheel.

## 9. Topics, frames and sensors

### ROS topics

The bridge (`config/gz_bridge.yaml`) exposes the same topics for every robot:

| Topic | Type | Direction | Rate |
|---|---|---|---|
| `/cmd_vel` | `geometry_msgs/msg/Twist` | ROS → Gazebo | input |
| `/scan` | `sensor_msgs/msg/LaserScan` | Gazebo → ROS | 10 Hz |
| `/camera/image_raw` | `sensor_msgs/msg/Image` | Gazebo → ROS | 30 Hz |
| `/camera/depth/image_raw` | `sensor_msgs/msg/Image` | Gazebo → ROS | 30 Hz |
| `/camera/camera_info` | `sensor_msgs/msg/CameraInfo` | Gazebo → ROS | 30 Hz |
| `/imu` | `sensor_msgs/msg/Imu` | Gazebo → ROS | 100 Hz |
| `/odom` | `nav_msgs/msg/Odometry` | Gazebo → ROS | 50 Hz |
| `/tf` | `tf2_msgs/msg/TFMessage` | Gazebo → ROS | `odom → base_link` |
| `/joint_states` | `sensor_msgs/msg/JointState` | Gazebo → ROS | wheel and steering joints |
| `/clock` | `rosgraph_msgs/msg/Clock` | Gazebo → ROS | simulation time |

`robot_state_publisher` publishes the robot's fixed and moving frames on
`/tf` and `/tf_static`. Gazebo also publishes a `camera/points` cloud, but it
isn't bridged: Gazebo stamps it with the optical frame, while the cloud is
in the x-forward frame, so it would appear rotated in ROS.

### TF tree

```
odom
└── base_link                      (from Gazebo odometry)
    ├── wheel / track / steering links
    └── mounting_plate
        ├── laser                  (lidar, x forward, z up)
        └── camera_link            (x forward, z up)
            └── camera_optical_frame   (z forward, x right, y down: ROS optical convention)
```

`/odom` uses frame `odom` and child frame `base_link`.

### Sensors

| Sensor | Gazebo type | Frame | Specification |
|---|---|---|---|
| RPLidar C1 | `gpu_lidar` | `laser` | 360°, 500 samples (0.72°), 0.05–12 m, 10 Hz, Gaussian noise σ = 1 cm |
| RealSense-style RGB-D camera | `rgbd_camera` | `camera_optical_frame` | 640 × 480, 30 Hz, 69° horizontal FOV, range 0.1–10 m |
| IMU | `imu` | `base_link` | 100 Hz |

To move the sensor mount along the deck, change the `x` of
`sensor_mount_joint` in the robot's URDF.

## 10. Using a newly generated field

`maize_field`, `tomato_field` and `lettuce_field` are fixed copies kept in
this repository. To use a field you have just generated instead, you need
the `virtual_maize_field` package:

```bash
ros2 run virtual_maize_field generate_world tomato_field
ros2 launch hunter_se_description generated_field.launch.py robot:=ranger_mini
```

`generated_field.launch.py` reads the world and start pose the generator
wrote to `~/.ros/virtual_maize_field/`. Generated worlds lack the sensors
plugin, so it adds that, then starts the chosen robot's `gazebo.launch.py`
(`robot` is `hunter_se`, `bunker_mini` or `ranger_mini`; the default is
`ranger_mini`).

To keep a generated field in the repo permanently:

1. copy its world into `hunter_se_description/worlds/` and its models into
   `hunter_se_description/models/`,
2. add the `gz-sim-sensors-system` plugin to the world if it isn't there,
3. copy one of the `*_field.launch.py` files in each robot package, then
   change the world name and the start pose (the generator writes the pose
   into `robot_spawner.launch.py`).

## 11. Troubleshooting

**The robot doesn't appear, or the Gazebo window stays empty.**
A Gazebo from an earlier launch is probably still running, often one that
was paused with Ctrl+Z. The launch file prints a warning when it finds one.
Stop it, then launch again:

```bash
pkill -9 -f "gz sim"
```

**`colcon build` fails with `No module named 'catkin_pkg'`.**
Another Python (for example `~/.local/bin/python3.11`, or a conda or
miniforge environment) is ahead of the system Python on your `PATH`. Either
deactivate that environment, or tell CMake which Python to use:

```bash
colcon build --symlink-install --cmake-args -DPython3_EXECUTABLE=/usr/bin/python3
```

**`package 'hunter_se_description' not found`.**
The field launch files of every robot load their worlds from
`hunter_se_description`. Build the whole workspace (don't use
`--packages-select` with only one robot) and source `install/setup.bash`.

**RViz shows nothing, but `ros2 topic echo` shows data.**
RViz is running on wall-clock time and drops the simulation-stamped messages.
Use `rviz:=true` on the simulation launch, which sets `use_sim_time`, or run
`ros2 param set /rviz2 use_sim_time true`.

**`libEGL warning: egl: failed to create dri2 screen` with `headless:=true`.**
This is harmless; the sensors still publish.

**`/odom` starts at a different place on each robot.**
On the Hunter SE and the Bunker Mini, `/odom` starts at (0, 0) where the
robot spawned. On the Ranger Mini (`OdometryPublisher` plugin), it reports
the robot's position in the world, so in a field it starts at the spawn pose,
for example (-1.46, -11.22) in the tomato field. Allow for this when your
code compares positions between robots.

**The robot doesn't move when I press keys.**
Click on the teleop terminal first; it only reads keys while it has focus.
Check that the command arrives with `ros2 topic echo /cmd_vel`. If the
teleop runs in a terminal where `ROS_DOMAIN_ID` differs from the
simulation's, it publishes into another domain: set the same value in both,
or in neither. On the Hunter SE, `j` and `l` do nothing; use `u` / `o`.

**The robot keeps moving after I let go of the key.**
That is how `teleop_twist_keyboard` works: a key press is a command that
lasts until the next one. Press `k` to stop.

**Other software on the same network sees these topics.**
Use a separate ROS domain, for example `export ROS_DOMAIN_ID=42`, in every
terminal you use with the simulation.

## 12. Repository layout

```
FRE2027/
├── README.md
├── hunter_se_description/
│   ├── config/gz_bridge.yaml        ROS <-> Gazebo topic bridge
│   ├── launch/                      description, gazebo, generated_field, *_field
│   ├── meshes/                      robot meshes
│   ├── models/                      plant, heightmap and material models of the fields
│   ├── rviz/                        rviz.rviz (model), sensors.rviz (simulation)
│   ├── urdf/                        hunter_se_description.urdf (+ .xacro)
│   └── worlds/                      sensor_test, maize_field, tomato_field, lettuce_field (.sdf)
├── bunker_mini_description/
│   ├── config/gz_bridge.yaml
│   ├── launch/                      description, gazebo, *_field
│   ├── meshes/
│   ├── rviz/                        display.rviz (model), sensors.rviz (simulation)
│   ├── urdf/bunker_mini.urdf
│   └── worlds/sensor_test.sdf
└── ranger_mini_description/
    ├── config/gz_bridge.yaml        also bridges the steering/ and wheel/ commands
    ├── launch/                      description, gazebo, *_field
    ├── meshes/
    ├── rviz/
    ├── scripts/four_ws_controller.py   cmd_vel -> 4 steering angles + 4 wheel speeds
    ├── urdf/ranger_mini.urdf
    └── worlds/sensor_test.sdf
```

The robot models come from
[agilexrobotics/ugv_gazebo_sim](https://github.com/agilexrobotics/ugv_gazebo_sim)
(humble branch), ported from Gazebo Classic to Gazebo Harmonic.
