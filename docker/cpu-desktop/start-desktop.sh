#!/bin/bash
# Starts the CPU image's browser desktop:
#   Xvnc (TigerVNC)  virtual X display :1 with a VNC server on localhost:5901
#   Openbox          window manager (opens a terminal, see
#                    /etc/xdg/openbox/autostart)
#   websockify       serves noVNC on port 8080 and relays it to the VNC server
#                    (novnc-server.py: websockify that tells browsers not to cache)
# Settings come from the environment (docker-compose.yml).
set -euo pipefail

# Optional VNC password (VNC passwords use only the first 8 characters).
security=(-SecurityTypes None)
if [ "${SELKIES_ENABLE_BASIC_AUTH:-false}" = "true" ]; then
    mkdir -p ~/.vnc
    echo "${PASSWD:?set PASSWD to use a password}" | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
    security=(-SecurityTypes VncAuth -PasswordFile "$HOME/.vnc/passwd")
fi

# Leftovers from a previous run of this container.
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

Xvnc "$DISPLAY" \
    -geometry "${DISPLAY_SIZEW:-1920}x${DISPLAY_SIZEH:-1080}" \
    -depth "${DISPLAY_CDEPTH:-24}" \
    -dpi "${DISPLAY_DPI:-96}" \
    -FrameRate "${DISPLAY_REFRESH:-30}" \
    -localhost -rfbport 5901 -AlwaysShared \
    "${security[@]}" &

for _ in $(seq 100); do
    [ -S /tmp/.X11-unix/X1 ] && break
    sleep 0.1
done

dbus-launch --exit-with-session openbox-session &
novnc-server.py --web /opt/novnc 8080 localhost:5901 &

echo "Desktop ready: open http://127.0.0.1:8080"
# Stop the container if any of them exits.
wait -n
