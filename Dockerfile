# =============================================================================
# ROS 2 Jazzy + Gazebo Harmonic workspace, served as a GPU-accelerated desktop
# in the browser (Selkies / WebRTC) on port 8080.
#
# Build:  docker compose build        (or: docker build -t fre2027-ws .)
# Run:    docker compose up -d        then open http://127.0.0.1:8080
#
# The base image runs as the non-root user "ubuntu" (UID 1000). Its `sudo` is
# actually `fakeroot` (system files are owned by "ubuntu"), which is enough
# for apt-get; system-level commands below use it.
# =============================================================================

# Ubuntu 24.04 desktop with NVIDIA EGL support. Pinned to an exact tag so
# builds are reproducible.
FROM ghcr.io/selkies-project/nvidia-egl-desktop:24.04-20241222100454

# Use bash for RUN (needed for `source`) and make any failure inside a pipe
# fail the whole command instead of being silently ignored.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Prevent apt from prompting for input during the build.
ENV DEBIAN_FRONTEND=noninteractive

ARG ROS_DISTRO=jazzy
ENV ROS_DISTRO=${ROS_DISTRO}

# The base image ships a Google Chrome apt repository whose signing key is
# out of date (NO_PUBKEY FD533C07C264648F), which makes every
# `apt-get update` fail. Chrome updates are not needed here, so drop that
# repository; Chrome itself stays installed. (`|| true`: no match is fine.)
RUN { sudo grep -rl "dl.google.com" /etc/apt/sources.list.d/ || true; } \
        | xargs -r sudo rm -f

# -----------------------------------------------------------------------------
# 1. General development tools
# -----------------------------------------------------------------------------
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        lsb-release \
        bash-completion \
        command-not-found \
        software-properties-common \
        xdg-user-dirs \
        wget \
        build-essential \
        cmake \
        gdb \
        git \
        openssh-client \
        python3-argcomplete \
        python3-pip \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. ROS 2 Jazzy + Gazebo Harmonic
#    - ros-jazzy-desktop : core ROS 2, RViz, demos
#    - ros-dev-tools     : colcon, rosdep, vcstool, etc.
#    - ros-jazzy-ros-gz  : ROS <-> Gazebo bridge. On Jazzy this pulls in
#                          Gazebo Harmonic from the ROS repo (gz_*_vendor
#                          packages), so the separate OSRF repo is not needed.
# -----------------------------------------------------------------------------
RUN sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && sudo apt-get update && sudo apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-desktop \
        ros-dev-tools \
        ros-${ROS_DISTRO}-ros-gz \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 3. rosdep
#    `rosdep init` writes to /etc/ros, so it needs root. `rosdep update` must
#    run as the normal user so the cache lands in /home/ubuntu/.ros, where
#    later `rosdep install` calls (also as "ubuntu") will find it.
# -----------------------------------------------------------------------------
RUN sudo rosdep init && rosdep update --rosdistro ${ROS_DISTRO}

# -----------------------------------------------------------------------------
# 4. Workspace
#    Create the workspace as "ubuntu" (not root, which is what WORKDIR would
#    use) so that colcon can write build/, install/ and log/ here.
# -----------------------------------------------------------------------------
RUN mkdir -p /home/ubuntu/ros2_ws/src
WORKDIR /home/ubuntu/ros2_ws

# Copy only the package manifests first and install their dependencies.
# This layer is cached and is only rebuilt when a package.xml changes, so
# editing source code does not trigger a full dependency reinstall.
COPY --chown=1000:1000 parc_robot/package.xml             src/parc_robot/package.xml
COPY --chown=1000:1000 parc_robot_bringup/package.xml     src/parc_robot_bringup/package.xml
COPY --chown=1000:1000 parc_robot_description/package.xml src/parc_robot_description/package.xml

# Note: in this base image `sudo` is a symlink to `fakeroot` (system files are
# owned by "ubuntu", fakeroot just makes apt believe it runs as root).
# fakeroot rejects the `sudo -H` that rosdep normally uses, so rosdep itself
# is run under `sudo` and told not to add its own (`--as-root apt:false`).
# HOME is unchanged under fakeroot, so the rosdep cache from step 3 is found.
# No `-r` flag: a missing dependency should fail the build, not be ignored.
RUN sudo apt-get update \
    && source /opt/ros/${ROS_DISTRO}/setup.bash \
    && sudo rosdep install --from-paths src --ignore-src --rosdistro ${ROS_DISTRO} -y \
        --as-root apt:false \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*

# Copy the rest of the project (see .dockerignore for what is excluded).
COPY --chown=1000:1000 . src/

# Build the packages. --symlink-install links launch, URDF and config files
# back to src/, so when docker-compose mounts the host repo over src/, edits
# to those files take effect without rebuilding.
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && colcon build --symlink-install

# -----------------------------------------------------------------------------
# 5. Shell setup: source ROS and the workspace in every new terminal.
# -----------------------------------------------------------------------------
RUN { \
        echo "source /opt/ros/${ROS_DISTRO}/setup.bash"; \
        echo "source /home/ubuntu/ros2_ws/install/setup.bash"; \
        echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash"; \
    } >> /home/ubuntu/.bashrc
