# FRE2027

Simulation of three AgileX field robots for the Field Robot Event 2027, built
on **ROS 2 Jazzy** and **Gazebo Harmonic** (`gz sim`).

- **Three robots**: Hunter SE (car-like steering), Bunker Mini (tracked) and
  Ranger Mini (four-wheel steering). Each carries the same sensor mount (an
  RPLidar C1 lidar, a RealSense-style RGB-D camera, and an IMU) and
  publishes the same ROS topics, so code written for one robot runs on the
  others.
- **Four worlds**: maize, tomato and lettuce fields made with
  [`virtual_maize_field`](https://github.com/FieldRobotEvent/virtual_maize_field),
  plus a flat world for checking the sensors.
- **One command** starts any robot in any world. The robots are driven
  with the standard `teleop_twist_keyboard`, or with your own code on
  `/cmd_vel`.

**Recommended setup: Docker.** The container comes with ROS, Gazebo and
this workspace ready to use, on a desktop that opens in your web browser.
Follow [section 1](#1-getting-started-with-docker-recommended) first, then
everything after it works the same inside the container.
If you'd rather install ROS on your own machine, see
[section 2](#2-native-install-without-docker).

## Demo

<!-- Drag roscon_github.mp4 into GitHub's web editor on this line; GitHub replaces it with a
     https://github.com/user-attachments/assets/... link, which plays inline. -->
VIDEO_LINK_HERE
https://github.com/user-attachments/assets/b1955eea-f626-454f-8ad4-18003cac06b8
---

## Contents

1. [Getting started with Docker (recommended)](#1-getting-started-with-docker-recommended)
2. [Native install (without Docker)](#2-native-install-without-docker)
3. [Running the simulation](#3-running-the-simulation)
4. [Driving the robots (teleoperation)](#4-driving-the-robots-teleoperation)
5. [Launch files and arguments](#5-launch-files-and-arguments)
6. [Packages](#6-packages)
7. [The robots](#7-the-robots)
8. [The worlds](#8-the-worlds)
9. [Topics, frames and sensors](#9-topics-frames-and-sensors)
10. [Using a newly generated field](#10-using-a-newly-generated-field)
11. [Troubleshooting](#11-troubleshooting)
12. [Repository layout](#12-repository-layout)

---

## 1. Getting started with Docker (recommended)

The container provides an Ubuntu 24.04 desktop with ROS 2 Jazzy, Gazebo
Harmonic, `teleop_twist_keyboard` and this workspace already built. You use
it **in your web browser**.

There are two ways to run it. Pick one before you start:

| Setup | Use it when | Gazebo renders on | Desktop streamed with | Image size |
|---|---|---|---|---|
| **GPU** (default) | The machine running Docker has an NVIDIA GPU | the GPU | Selkies WebRTC, or KasmVNC if UDP is blocked | about 15.5 GB |
| **CPU** | No NVIDIA GPU (Intel/AMD graphics, laptops, most cloud VMs) | the CPU (software OpenGL) | noVNC | about 4 GB |

The GPU setup is built on the
[docker-nvidia-egl-desktop](https://github.com/selkies-project/docker-nvidia-egl-desktop)
image. The CPU setup uses its own, much smaller image built on plain
Ubuntu 24.04, without any NVIDIA software, and the same workspace. Its
simulation is much slower: in the maize field it runs at about 5–10 % of
real time, with the lidar publishing about 1–2 times a second instead of
10 times. That's enough to try out the robots and develop code, but not for
timing-sensitive work.

Selkies WebRTC sends the video over **UDP**. KasmVNC and noVNC use only the
TCP port 8080, so they also work through firewalls, VPNs and SSH tunnels that block
UDP. See [Running on a remote machine](#running-on-a-remote-machine).

### Step 1: Prepare the host (once per machine)

You need:

| Requirement | Setup | Check that it works |
|---|---|---|
| Linux with Docker Engine and the Compose plugin ([install guide](https://docs.docker.com/engine/install/ubuntu/)) | both | `docker compose version` |
| Docker usable without `sudo` | both | `docker run --rm hello-world` |
| Free disk space: about 30 GB for the GPU setup, about 8 GB for the CPU setup | both | `df -h /var/lib/docker` |
| An NVIDIA GPU and its driver | GPU only | `nvidia-smi` lists your GPU |
| [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) | GPU only | `docker info \| grep -i runtimes` lists `nvidia` |

To use Docker without `sudo`, add yourself to the `docker` group, then log
out and back in:

```bash
sudo usermod -aG docker $USER
```

For the GPU setup, after installing the NVIDIA Container Toolkit, register
it with Docker:

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Step 2: Clone the repository

```bash
git clone https://github.com/EASOUMO/FRE2027.git
cd FRE2027
```

### Step 3: Build the image and start the container

Each setup has its own image, built from a different target of the
`Dockerfile` in the repository root: `fre2027-ws:latest` (GPU, target `gpu`)
and `fre2027-ws:cpu` (CPU, target `cpu`). The build:

1. starts from the base image: `ghcr.io/selkies-project/nvidia-egl-desktop`
   (GPU, about 12.5 GB on disk) or `ubuntu:24.04` (CPU) plus a small
   TigerVNC + noVNC + Openbox desktop,
2. installs ROS 2 Jazzy (`ros-base`, RViz), colcon, rosdep and `teleop_twist_keyboard`,
3. installs the packages' dependencies with `rosdep`, including Gazebo Harmonic,
4. copies the repository into `/home/ubuntu/ros2_ws/src` and builds it with
   `colcon build --symlink-install`.

Run one of these in the repository root, the folder that contains
`docker-compose.yml`. Each builds the image if needed, then starts the
container:

```bash
docker compose up -d --build                  # GPU setup
docker compose up -d --build FRE2027_ws_cpu   # CPU setup
```

The first build takes roughly 10–30 minutes, depending on your connection,
and the finished image takes about 15.5 GB (GPU) or 4 GB (CPU). Later
starts take seconds.

To only build the image, without starting anything:

```bash
docker compose build                  # GPU setup
docker compose build FRE2027_ws_cpu   # CPU setup
```

Check that the container is running:

```bash
docker compose ps                  # GPU setup: STATUS should be "Up"
docker compose --profile cpu ps    # CPU setup: FRE2027_ws_cpu should be "Up"
```

**When to rebuild.** You don't need to rebuild after editing code, URDFs,
worlds or launch files: the repository is mounted into the container (see
[Editing files](#editing-files)). Rebuild with the same `up -d --build`
command after changing a `package.xml`, the `Dockerfile` or
`docker-compose.yml`. Docker reuses the cached steps, so only the changed
part is redone.

**If the build fails:**

- `apt-get update` or a download fails: check your internet connection and
  run the command again. Docker resumes from the last completed step.
- `no space left on device`: free space with `docker system prune` (it
  removes stopped containers and the unused build cache), then try again.
- To rebuild from scratch, ignoring the cache:
  `docker compose build --no-cache`.

### Step 4: Open the desktop

Open **http://127.0.0.1:8080** in your web browser; no login is needed.
If Docker runs on another machine, see
[Running on a remote machine](#running-on-a-remote-machine) first.
On the desktop, open a terminal: in the GPU setup, **Konsole** in the
application menu at the bottom left. The CPU setup opens one when it starts;
for more, **right-click the desktop background** and pick **Terminal**. That
menu's **Windows** entry brings back minimized windows.

Every new terminal in the container already has ROS and the workspace
sourced. The workspace is in `/home/ubuntu/ros2_ws`, and this repository is
at `/home/ubuntu/ros2_ws/src`.

### Step 5: Run your first simulation

In the container terminal:

```bash
ros2 launch bunker_mini_description maize_field.launch.py
```

Gazebo opens with the Bunker Mini at the start of the maize field. Open a
**second terminal** and start the keyboard teleop:

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

With that terminal focused, press `i` to drive forward, `j` / `l` to turn
and `k` to stop. Each key is pressed **once**: the robot keeps going until
the next key. See [section 4](#4-driving-the-robots-teleoperation) for all
the keys.

You're set up. Every command from [section 3](#3-running-the-simulation)
onwards runs in a container terminal like this one.

### Running on a remote machine

If Docker runs on a server or workstation that you reach over the network,
don't open port 8080 to the network: the desktop has no login. Forward it
through SSH instead. On **your own computer**:

```bash
ssh -L 8080:127.0.0.1:8080 user@remote-machine
```

Keep that SSH session open and browse to **http://127.0.0.1:8080** on your
own computer.

The SSH tunnel only carries TCP, so Selkies WebRTC's UDP video can't go
through it, and the page loads but never shows the desktop. Use KasmVNC or noVNC
instead:

- **Remote machine has an NVIDIA GPU:** use the GPU setup with KasmVNC. Put
  `KASMVNC_ENABLE=true` in a `.env` file next to `docker-compose.yml` on the
  remote machine, then run `docker compose up -d`. Gazebo still renders on
  the GPU at full speed; only the desktop video changes.
- **No NVIDIA GPU:** use the CPU setup (`docker compose up -d FRE2027_ws_cpu`).
  It always uses noVNC.

### Everyday Docker commands

Run these on the host, in the repository root. For the CPU setup, add
`FRE2027_ws_cpu` to `up`, `build` and `logs`
(`docker compose up -d FRE2027_ws_cpu`), use
`docker compose --profile cpu stop` / `down` / `ps`, and use
`FRE2027_ws_cpu` as the container name in `docker exec`.

| Command | What it does |
|---|---|
| `docker compose up -d` | Start the container; it reuses the image if already built. |
| `docker compose up -d --build` | Rebuild the image, then start. Needed after changing a `package.xml`, the `Dockerfile` or `docker-compose.yml`. |
| `docker compose stop` | Stop the container and keep it, including anything built inside. |
| `docker compose down` | Stop and remove the container. Your repository files are kept. |
| `docker compose ps` | Show whether the container is running. |
| `docker compose logs -f` | Follow the desktop's log, if the page doesn't load. |
| `docker exec -it FRE2027_ws bash` | Open a shell in the running container, without the browser. GUI programs started from it (Gazebo, RViz) still appear on the web desktop. |
| `docker image prune` | Delete old, untagged images left behind by rebuilds, to free disk space. |

### Editing files

The repository on your host is mounted into the container as the
workspace's `src/` folder (`./` → `/home/ubuntu/ros2_ws/src`):

- Edit with your usual editor on the host, or inside the container. Both
  see the same files, and nothing is lost when the container is removed.
- The image is built with `--symlink-install`, so changes to existing
  URDFs, worlds, launch files and configs take effect on the next launch,
  without rebuilding.
- After **adding** a file or a package, rebuild inside the container:

  ```bash
  cd ~/ros2_ws && colcon build --symlink-install && source install/setup.bash
  ```

  That build stays in the container until `docker compose down`. To bake it
  into the image, run `docker compose up -d --build`.
- The container user `ubuntu` has UID 1000. If your host user's UID differs
  (`id -u`), files created inside the container will belong to a different
  user on the host.

### Settings

Put optional settings in a `.env` file next to `docker-compose.yml`. It is
excluded from the image by `.dockerignore`; don't commit it.

| Variable | Default | Meaning |
|---|---|---|
| `PASSWD` | `fre2027` | GPU setup: password of the `ubuntu` account inside the container, for when a program asks for it. CPU setup: `sudo` needs no password; `PASSWD` is only used as the desktop password when `SELKIES_ENABLE_BASIC_AUTH=true` (VNC uses only its first 8 characters). |
| `HOST_BIND` | `127.0.0.1` | Address the desktop listens on. With the default, only this computer can open it. `0.0.0.0` opens it to your network, but **the desktop has no login**, so first set `SELKIES_ENABLE_BASIC_AUTH=true` in `docker-compose.yml`. To reach it from another computer, an SSH tunnel is safer (see [Running on a remote machine](#running-on-a-remote-machine)). |
| `KASMVNC_ENABLE` | `false` | GPU setup only. `true` streams the desktop with KasmVNC over TCP instead of Selkies WebRTC, which needs UDP. The CPU setup always uses noVNC. |

Example `.env`:

```bash
PASSWD=my-own-password
```

Screen size, frame rate and streaming bitrate are set in the `environment`
section of `docker-compose.yml` (`DISPLAY_SIZEW`, `DISPLAY_SIZEH`,
`SELKIES_FRAMERATE`, `SELKIES_VIDEO_BITRATE`). Apply a change with
`docker compose up -d`. In the CPU setup only `DISPLAY_SIZEW`,
`DISPLAY_SIZEH`, `DISPLAY_DPI` and `DISPLAY_REFRESH` apply, and noVNC
resizes the desktop to fit your browser window once connected.

---

## 2. Native install (without Docker)

Skip this section if you use Docker.

You need **Ubuntu 24.04** with **ROS 2 Jazzy** installed
([guide](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html)).
Then:

**1. Install the packages the simulation uses** (Gazebo Harmonic comes
with `ros-jazzy-ros-gz`):

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

**2. Clone the repository into a colcon workspace.** The repository root
holds the packages, so it goes inside `src/`:

```bash
mkdir -p ~/fre_ws/src
cd ~/fre_ws/src
git clone https://github.com/EASOUMO/FRE2027.git
```

**3. Install any missing dependencies, then build:**

```bash
cd ~/fre_ws
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src -y
colcon build --symlink-install
```

If the build fails with `No module named 'catkin_pkg'`, see
[Troubleshooting](#11-troubleshooting).

**4. Source the workspace in every terminal.** Add it to `~/.bashrc` so
that happens automatically:

```bash
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
echo "source ~/fre_ws/install/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

`--symlink-install` links the installed files to the source tree, so
changes to existing URDFs, worlds and launch files take effect without
rebuilding. A new file needs `colcon build` again.

---

## 3. Running the simulation

Run these in a terminal **inside the container** (or, on a native install,
in any sourced terminal).

### Start a robot in a world

Choose a robot package and a world:

```bash
# <robot> is hunter_se, bunker_mini or ranger_mini
ros2 launch <robot>_description maize_field.launch.py
ros2 launch <robot>_description tomato_field.launch.py
ros2 launch <robot>_description lettuce_field.launch.py
ros2 launch <robot>_description gazebo.launch.py          # flat sensor_test world
```

For example:

```bash
ros2 launch ranger_mini_description tomato_field.launch.py
```

Then drive it from a second terminal with
`ros2 run teleop_twist_keyboard teleop_twist_keyboard`
([section 4](#4-driving-the-robots-teleoperation)).

### Common options

Options are added after the launch file name as `name:=value`:

```bash
# Also open RViz with the lidar scan, camera images and TF frames
ros2 launch ranger_mini_description tomato_field.launch.py visualization:=true

# No Gazebo window: faster, for long runs or recording data. The sensors still publish.
ros2 launch hunter_se_description maize_field.launch.py headless:=true

# Spawn somewhere else (metres, radians)
ros2 launch bunker_mini_description maize_field.launch.py x:=1.5 y:=-8.5 yaw:=1.57

# View only the robot model in RViz (no simulation), with sliders for the joints
ros2 launch ranger_mini_description description.launch.py
```

[Section 5](#5-launch-files-and-arguments) lists every option.

### Check that it works

In another terminal:

```bash
ros2 topic list                  # /scan, /camera/image_raw, /imu, /odom, /cmd_vel, ...
ros2 topic hz /scan              # about 10 Hz
ros2 topic echo /odom --once     # the robot's pose
```

### Stop the simulation

Press **Ctrl+C** in the terminal where you launched it. Don't use Ctrl+Z:
it pauses Gazebo without stopping it, and the paused Gazebo interferes
with the next launch (see [Troubleshooting](#11-troubleshooting)).

---

## 4. Driving the robots (teleoperation)

All three robots take `geometry_msgs/msg/Twist` on **`/cmd_vel`**:
`linear.x` is the forward speed in m/s, `linear.y` the sideways speed (Ranger
Mini only) and `angular.z` the yaw rate in rad/s. Drive them with the
standard ROS keyboard teleop.

### Keyboard teleop

Start a simulation ([section 3](#3-running-the-simulation)), then run
this in a **second terminal**:

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

Keep that terminal focused while driving: it reads keys only when it is the
active window. The Docker image already includes `teleop_twist_keyboard`;
on a native install it comes from `ros-jazzy-teleop-twist-keyboard`.

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

---

## 5. Launch files and arguments

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
7. if `visualization:=true` (or `rviz:=true`), opens RViz with `rviz/sensors.rviz`.

It also warns you if another Gazebo is already running.

| Argument | Default | Meaning |
|---|---|---|
| `world` | `<pkg>/worlds/sensor_test.sdf` | SDF world to load; it must contain the `gz-sim-sensors-system` plugin |
| `model` | `<pkg>/urdf/<robot>.urdf` | Robot URDF or xacro file |
| `model_path` | `<pkg>/worlds` | Extra directory searched for `model://` URIs (Bunker and Ranger only; the Hunter SE always searches its own `models/`) |
| `headless` | `false` | `true` runs the Gazebo server only, with headless rendering (sensors still work) |
| `visualization` | `false` | `true` opens RViz with `rviz/sensors.rviz` (lidar scan, camera images, TF, robot model) |
| `rviz` | `false` | same as `visualization`; either one set to `true` opens RViz |
| `x`, `y`, `z`, `yaw` | `0`, `0`, height above ground, `0` | Spawn pose, in metres and radians |

Every node is started with `use_sim_time: true`.

### `maize_field.launch.py`, `tomato_field.launch.py`, `lettuce_field.launch.py`

These call `gazebo.launch.py` with the field's world from
`hunter_se_description/worlds/`, set `model_path` to
`hunter_se_description/models/`, and set the spawn pose to the field's
start pose (see [the worlds](#8-the-worlds)).

They accept `world`, `headless`, `visualization`, `rviz`, `x`, `y`, `z` and `yaw`, and pass
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

---

## 6. Packages

| Package | What it contains |
|---|---|
| `hunter_se_description` | The **Hunter SE** robot, **plus the three field worlds and all their plant and terrain models**. The other two packages load their fields from here, so it is always required. |
| `bunker_mini_description` | The **Bunker Mini** robot: URDF, meshes, Gazebo bridge config, RViz configs and launch files. |
| `ranger_mini_description` | The **Ranger Mini** robot: the same files, plus `four_ws_controller.py`, which turns `cmd_vel` into steering angles and wheel speeds. |

All three are `ament_cmake` packages that install their files only; nothing is
compiled.

## 7. The robots

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

## 8. The worlds

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

---

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

---

## 11. Troubleshooting

### Docker

**`docker compose up` fails with `could not select device driver "nvidia"`.**
The NVIDIA Container Toolkit isn't installed or isn't registered with
Docker. Do step 1 of [section 1](#1-getting-started-with-docker-recommended),
then check that `docker info | grep -i runtimes` lists `nvidia`.

**`permission denied while trying to connect to the Docker daemon socket`.**
Your user isn't in the `docker` group. Run `sudo usermod -aG docker $USER`,
then log out and back in.

**The page at http://127.0.0.1:8080 loads, but the desktop never appears**
(it stays black or keeps saying it is connecting). Selkies WebRTC can't get
its UDP video through, which is typical over SSH tunnels, VPNs and strict
firewalls. Set `KASMVNC_ENABLE=true` in `.env` and run `docker compose up -d`,
or use the CPU setup. See
[Running on a remote machine](#running-on-a-remote-machine).

**`docker compose up` fails with `could not select device driver "nvidia"`
and the machine has no NVIDIA GPU.** Use the CPU setup:
`docker compose up -d --build FRE2027_ws_cpu`.

**The CPU setup is very slow.** That's expected: without a GPU, the lidar
and the RGB-D camera are rendered in software. Close the Gazebo window with
`headless:=true` to save a little, or use a machine with an NVIDIA GPU
(locally or remotely through KasmVNC).

**CPU setup: no terminal on the desktop.** Right-click the desktop
background and pick **Terminal**. If a window disappeared after being
minimized, the same menu's **Windows** entry lists it.

**CPU setup: `rosdep install` says the cache is missing or out of date.**
The CPU image deletes the rosdep cache to stay small. Run `rosdep update`
once in the container, then `rosdep install` again.

**CPU setup: a package installed with `sudo apt install` is missing a
feature.** Both images tell apt to skip "recommended" packages to stay
small. Add `--install-recommends` if you need them.

**http://127.0.0.1:8080 doesn't load.**
Check `docker compose ps` (it should say `Up`) and
`docker compose logs -f`. The desktop needs a few seconds after the
container starts. If another program already uses port 8080, change the
left-hand port in `docker-compose.yml`, for example
`'${HOST_BIND:-127.0.0.1}:8081:8080'`, then open port 8081.

**The build fails at `apt-get update` or `rosdep`.**
This is usually a network or mirror problem; run `docker compose build`
again. If it fails at the `rosdep install` step after you changed a
`package.xml`, the message names the dependency that has no apt package.

**A new package isn't found inside the container.**
Rebuild in the container: `cd ~/ros2_ws && colcon build --symlink-install && source install/setup.bash`.

### Build (native install)

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

### Simulation

**The robot doesn't appear, or the Gazebo window stays empty.**
A Gazebo from an earlier launch is probably still running, often one that
was paused with Ctrl+Z. The launch file prints a warning when it finds one.
Stop it, then launch again:

```bash
pkill -9 -f "gz sim"
```

**RViz shows nothing, but `ros2 topic echo` shows data.**
RViz is running on wall-clock time and drops the simulation-stamped messages.
Use `visualization:=true` on the simulation launch, which sets `use_sim_time`, or run
`ros2 param set /rviz2 use_sim_time true`.

**`libEGL warning: egl: failed to create dri2 screen` with `headless:=true`.**
This is harmless; the sensors still publish.

**`/odom` starts at a different place on each robot.**
On the Hunter SE and the Bunker Mini, `/odom` starts at (0, 0) where the
robot spawned. On the Ranger Mini (`OdometryPublisher` plugin), it reports
the robot's position in the world, so in a field it starts at the spawn pose,
for example (-1.46, -11.22) in the tomato field. Allow for this when your
code compares positions between robots.

**Other software on the same network sees these topics.**
Use a separate ROS domain, for example `export ROS_DOMAIN_ID=42`, in every
terminal you use with the simulation.

### Teleoperation

**The robot doesn't move when I press keys.**
Click on the teleop terminal first; it only reads keys while it has focus.
Check that the command arrives with `ros2 topic echo /cmd_vel`. If the
teleop runs in a terminal where `ROS_DOMAIN_ID` differs from the
simulation's, it publishes into another domain: set the same value in both,
or in neither. On the Hunter SE, `j` and `l` do nothing; use `u` / `o`.

**The robot keeps moving after I let go of the key.**
That is how `teleop_twist_keyboard` works: a key press is a command that
lasts until the next one. Press `k` to stop.

---

## 12. Repository layout

```
FRE2027/
├── README.md
├── Dockerfile                       ROS 2 Jazzy + Gazebo desktop image (section 1)
├── docker-compose.yml               runs it, desktop on http://127.0.0.1:8080
├── .dockerignore
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
