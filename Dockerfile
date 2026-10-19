# =============================================================================
# ROS 2 Jazzy + Gazebo Harmonic workspace, served as a desktop in the browser
# on port 8080. Two image variants (build targets) share this file:
#
#   cpu : plain Ubuntu 24.04, no NVIDIA libraries. Software OpenGL (Mesa
#         llvmpipe), TigerVNC + noVNC desktop. Small image.
#   gpu : Selkies NVIDIA EGL desktop (WebRTC / KasmVNC streaming, NVIDIA
#         hardware rendering and encoding). Default target.
#
# Build:  docker compose build                    (GPU, fre2027-ws:latest)
#         docker compose build FRE2027_ws_cpu     (CPU, fre2027-ws:cpu)
#    or:  docker build --target cpu -t fre2027-ws:cpu .
#
# Both variants install only what the workspace needs: ROS 2 base, RViz,
# teleop_twist_keyboard, colcon/rosdep, and the packages' rosdep
# dependencies (ros_gz, xacro, joint_state_publisher_gui, ...). Not the full
# `ros-jazzy-desktop` (demos, tutorials, rqt plugins, ...).
# =============================================================================

ARG ROS_DISTRO=jazzy
ARG NOVNC_VERSION=1.5.0


# =============================================================================
# CPU image
# =============================================================================
FROM ubuntu:24.04 AS cpu

# Use bash for RUN (needed for `source`) and make any failure inside a pipe
# fail the whole command instead of being silently ignored.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG ROS_DISTRO
ARG NOVNC_VERSION
ENV ROS_DISTRO=${ROS_DISTRO} \
    DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    DISPLAY=:1

# Never install "recommended" or "suggested" packages, also not when rosdep
# calls apt. This alone saves several hundred MB.
RUN printf 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";\n' \
        > /etc/apt/apt.conf.d/99-no-recommends

# -----------------------------------------------------------------------------
# 1. ROS 2 Jazzy (base + RViz), build tools, keyboard teleop
#    Gazebo Harmonic comes later with ros_gz (rosdep, step 3).
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y ca-certificates curl \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        > /etc/apt/sources.list.d/ros2.list \
    && apt-get update && apt-get install -y \
        build-essential \
        cmake \
        git \
        python3-colcon-common-extensions \
        python3-rosdep \
        ros-${ROS_DISTRO}-ros-base \
        ros-${ROS_DISTRO}-rviz2 \
        ros-${ROS_DISTRO}-teleop-twist-keyboard \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Browser desktop
#    - tigervnc-standalone-server : virtual X server with a VNC server (Xvnc);
#                                   renders OpenGL in software via Mesa
#    - noVNC + python3-websockify : VNC client web page on port 8080. noVNC
#                                   comes from its release tarball: the apt
#                                   package pulls in Node.js and OpenStack libs
#    - openbox                    : window manager (right-click menu)
#    - xfce4-terminal             : terminal
#    - sudo                       : passwordless for "ubuntu" (apt-get, ...)
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
        tigervnc-standalone-server \
        tigervnc-tools \
        python3-websockify \
        openbox \
        xfce4-terminal \
        dbus-x11 \
        fonts-dejavu-core \
        libgl1-mesa-dri \
        bash-completion \
        sudo \
    && rm -rf /var/lib/apt/lists/* \
    && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu \
    && mkdir -m 1777 -p /tmp/.X11-unix \
    && mkdir -p /opt/novnc \
    && curl -sSL https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz \
        | tar -xz -C /opt/novnc --strip-components=1 \
            noVNC-${NOVNC_VERSION}/app noVNC-${NOVNC_VERSION}/core \
            noVNC-${NOVNC_VERSION}/vendor noVNC-${NOVNC_VERSION}/vnc.html \
    && echo '<meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&reconnect=true&resize=remote">' \
        > /opt/novnc/index.html

# -----------------------------------------------------------------------------
# 3. Workspace dependencies (rosdep)
#    The ubuntu:24.04 image already has the user "ubuntu" (UID 1000).
#    Only the package manifests are copied first, so this layer is rebuilt
#    only when a package.xml changes. The rosdep cache is removed afterwards
#    (run `rosdep update` in the container if you need rosdep there).
#    No `-r` flag: a missing dependency should fail the build.
# -----------------------------------------------------------------------------
WORKDIR /home/ubuntu/ros2_ws
COPY hunter_se_description/package.xml   src/hunter_se_description/package.xml
COPY bunker_mini_description/package.xml src/bunker_mini_description/package.xml
COPY ranger_mini_description/package.xml src/ranger_mini_description/package.xml

RUN apt-get update \
    && rosdep init \
    && rosdep update --rosdistro ${ROS_DISTRO} \
    && rosdep install --from-paths src --ignore-src --rosdistro ${ROS_DISTRO} -y \
    && rm -rf /var/lib/apt/lists/* /root/.ros /root/.cache \
    && chown -R ubuntu:ubuntu /home/ubuntu

# -----------------------------------------------------------------------------
# 4. Build the workspace as "ubuntu" (see the gpu stage for --symlink-install)
# -----------------------------------------------------------------------------
USER ubuntu
COPY --chown=1000:1000 . src/
RUN source /opt/ros/${ROS_DISTRO}/setup.bash \
    && colcon build --symlink-install \
    && rm -rf log

# -----------------------------------------------------------------------------
# 5. Shell and desktop setup
# -----------------------------------------------------------------------------
RUN { \
        echo "source /opt/ros/${ROS_DISTRO}/setup.bash"; \
        echo "source /home/ubuntu/ros2_ws/install/setup.bash"; \
        echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash"; \
    } >> /home/ubuntu/.bashrc

COPY docker/cpu-desktop/openbox/ /etc/xdg/openbox/
COPY docker/cpu-desktop/start-desktop.sh /usr/local/bin/start-desktop.sh

EXPOSE 8080
CMD ["/usr/local/bin/start-desktop.sh"]


# =============================================================================
# GPU image (default target: keep it last)
# =============================================================================
# Ubuntu 24.04 desktop with NVIDIA EGL support. Pinned to an exact tag so
# builds are reproducible.
#
# The base image runs as the non-root user "ubuntu" (UID 1000). Its `sudo` is
# actually `fakeroot` (system files are owned by "ubuntu"), which is enough
# for apt-get; system-level commands below use it.
FROM ghcr.io/selkies-project/nvidia-egl-desktop:24.04-20241222100454 AS gpu

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

ARG ROS_DISTRO
ENV ROS_DISTRO=${ROS_DISTRO}

# The base image ships a Google Chrome apt repository whose signing key is
# out of date (NO_PUBKEY FD533C07C264648F), which makes every
# `apt-get update` fail. Chrome updates are not needed here, so drop that
# repository; Chrome itself stays installed. (`|| true`: no match is fine.)
RUN { sudo grep -rl "dl.google.com" /etc/apt/sources.list.d/ || true; } \
        | xargs -r sudo rm -f

# Never install "recommended" or "suggested" packages, also not when rosdep
# calls apt.
RUN printf 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";\n' \
        | sudo tee /etc/apt/apt.conf.d/99-no-recommends > /dev/null

# -----------------------------------------------------------------------------
# 1. ROS 2 Jazzy (base + RViz), build tools, keyboard teleop
#    Gazebo Harmonic comes later with ros_gz (rosdep, step 3): on Jazzy it
#    is installed from the ROS repo (gz_*_vendor packages).
#    teleop_twist_keyboard: no package.xml depends on it, so rosdep would
#    not install it.
# -----------------------------------------------------------------------------
RUN sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" \
        | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && sudo apt-get update && sudo apt-get install -y \
        build-essential \
        cmake \
        git \
        bash-completion \
        python3-colcon-common-extensions \
        python3-rosdep \
        ros-${ROS_DISTRO}-ros-base \
        ros-${ROS_DISTRO}-rviz2 \
        ros-${ROS_DISTRO}-teleop-twist-keyboard \
    && sudo apt-get clean \
    && sudo rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. rosdep
#    `rosdep init` writes to /etc/ros, so it needs root. `rosdep update` must
#    run as the normal user so the cache lands in /home/ubuntu/.ros, where
#    later `rosdep install` calls (also as "ubuntu") will find it.
# -----------------------------------------------------------------------------
RUN sudo rosdep init && rosdep update --rosdistro ${ROS_DISTRO}

# -----------------------------------------------------------------------------
# 3. Workspace
#    Create the workspace as "ubuntu" (not root, which is what WORKDIR would
#    use) so that colcon can write build/, install/ and log/ here.
# -----------------------------------------------------------------------------
RUN mkdir -p /home/ubuntu/ros2_ws/src
WORKDIR /home/ubuntu/ros2_ws

# Copy only the package manifests first and install their dependencies.
# This layer is cached and is only rebuilt when a package.xml changes, so
# editing source code does not trigger a full dependency reinstall.
COPY --chown=1000:1000 hunter_se_description/package.xml   src/hunter_se_description/package.xml
COPY --chown=1000:1000 bunker_mini_description/package.xml src/bunker_mini_description/package.xml
COPY --chown=1000:1000 ranger_mini_description/package.xml src/ranger_mini_description/package.xml

# Note: in this base image `sudo` is a symlink to `fakeroot` (system files are
# owned by "ubuntu", fakeroot just makes apt believe it runs as root).
# fakeroot rejects the `sudo -H` that rosdep normally uses, so rosdep itself
# is run under `sudo` and told not to add its own (`--as-root apt:false`).
# HOME is unchanged under fakeroot, so the rosdep cache from step 2 is found.
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
    && colcon build --symlink-install \
    && rm -rf log

# -----------------------------------------------------------------------------
# 4. Shell setup: source ROS and the workspace in every new terminal.
# -----------------------------------------------------------------------------
RUN { \
        echo "source /opt/ros/${ROS_DISTRO}/setup.bash"; \
        echo "source /home/ubuntu/ros2_ws/install/setup.bash"; \
        echo "source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash"; \
    } >> /home/ubuntu/.bashrc
