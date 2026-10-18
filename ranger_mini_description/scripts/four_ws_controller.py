#!/usr/bin/python3
"""cmd_vel -> steering angles and wheel speeds for the four-wheel-steering
Ranger Mini.

Each wheel at (x, y) from base_link must move with velocity
(vx - wz * y, vy + wz * x). Its steering angle is the direction of that
vector and its speed the length. That one rule gives every Ranger mode:
counter-steering front and rear for a turn (linear.x + angular.z), spinning
on the spot (angular.z alone) and crabbing sideways (linear.y).

A wheel never steers more than 90 degrees from straight ahead: beyond that it
is turned the short way and driven backwards instead.
"""

import math

import rclpy
from geometry_msgs.msg import Twist
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import Float64

# wheel name -> (x, y) of its steering axis from base_link, as in ranger_mini.urdf
WHEELS = {"fl": (0.245, 0.185), "fr": (0.245, -0.185), "rl": (-0.245, 0.185), "rr": (-0.245, -0.185)}


def wheel_commands(vx, vy, wz, wheels=WHEELS, wheel_radius=0.08, last_angles=None):
    """{name: (steering angle rad, wheel speed rad/s)}. With no motion
    commanded the wheels stop and keep the angles in `last_angles`."""
    out = {}
    for name, (x, y) in wheels.items():
        wx, wy = vx - wz * y, vy + wz * x
        speed = math.hypot(wx, wy)
        if speed < 1e-4:
            out[name] = ((last_angles or {}).get(name, 0.0), 0.0)
            continue
        angle = math.atan2(wy, wx)
        if angle > math.pi / 2.0:
            angle, speed = angle - math.pi, -speed
        elif angle < -math.pi / 2.0:
            angle, speed = angle + math.pi, -speed
        out[name] = (angle, speed / wheel_radius)
    return out


class FourWsController(Node):
    def __init__(self):
        super().__init__("four_ws_controller")
        self.declare_parameter("wheel_radius", 0.08)
        # s without cmd_vel before stopping; 0 keeps the last command, as the
        # Gazebo drive plugins of the Bunker Mini and Hunter SE do, so that
        # teleop_twist_keyboard (one message per key press) drives all three alike
        self.declare_parameter("cmd_vel_timeout", 0.0)
        self.declare_parameter("max_speed", 1.5)  # m/s at any wheel (Ranger Mini top speed)
        self.wheel_radius = float(self.get_parameter("wheel_radius").value)
        self.timeout = float(self.get_parameter("cmd_vel_timeout").value)
        self.max_speed = float(self.get_parameter("max_speed").value)
        self.steer_pubs = {n: self.create_publisher(Float64, f"steering/{n}", 10) for n in WHEELS}
        self.wheel_pubs = {n: self.create_publisher(Float64, f"wheel/{n}", 10) for n in WHEELS}
        self.cmd = (0.0, 0.0, 0.0)
        self.cmd_time = None
        self.angles = {n: 0.0 for n in WHEELS}
        self.create_subscription(Twist, "cmd_vel", self._cmd_cb, 10)
        self.create_timer(0.02, self._step)

    def _cmd_cb(self, msg):
        self.cmd = (msg.linear.x, msg.linear.y, msg.angular.z)
        self.cmd_time = self.get_clock().now()

    def _step(self):
        cmd = self.cmd
        if self.cmd_time is None or (
            self.timeout > 0.0 and (self.get_clock().now() - self.cmd_time).nanoseconds * 1e-9 > self.timeout
        ):
            cmd = (0.0, 0.0, 0.0)
        commands = wheel_commands(*cmd, wheel_radius=self.wheel_radius, last_angles=self.angles)
        fastest = max(abs(s) for _, s in commands.values()) * self.wheel_radius
        scale = self.max_speed / fastest if fastest > self.max_speed else 1.0
        for name, (angle, speed) in commands.items():
            self.angles[name] = angle
            self.steer_pubs[name].publish(Float64(data=angle))
            self.wheel_pubs[name].publish(Float64(data=speed * scale))


def main():
    rclpy.init()
    node = FourWsController()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        if rclpy.ok():
            rclpy.shutdown()


if __name__ == "__main__":
    main()
