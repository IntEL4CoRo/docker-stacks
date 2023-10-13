FROM jupyter/minimal-notebook:ubuntu-22.04

# --- Define Environment Variables--- #
ARG ROS_PKG=desktop
ENV ROS_DISTRO=iron
LABEL version="ROS-${ROS_DISTRO}-${ROS_PKG}"

ENV LANG=en_US.UTF-8
ENV DISPLAY=:100

ENV ROS_PATH=/opt/ros/${ROS_DISTRO}
ENV ROS_ROOT=${ROS_PATH}/share/ros
ENV ROS_WS=/home/${NB_USER}/workspace/ros

# --- Install Oh-my-bash --- #
USER ${NB_USER}
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
COPY --chown=${NB_USER}:users ./bashrc.sh /home/${NB_USER}/.bashrc

# --- Install basic tools --- #
USER root
RUN  apt update -q && apt install -y \
        software-properties-common \
        gnupg2 \
        net-tools\
        ca-certificates \
        apt-transport-https \
        build-essential \
        lsb-release

# --- Install ROS --- #
RUN add-apt-repository universe
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
RUN apt update && \
    apt install -y ros-dev-tools && \
    apt upgrade -y && \
    apt install -y ros-${ROS_DISTRO}-${ROS_PKG} && \
    apt clean && \
    echo "source ${ROS_PATH}/setup.bash" >> /root/.bashrc && \
    echo "source ${ROS_PATH}/setup.bash" >> /home/${NB_USER}/.bashrc

# --- Install XPRA and GUI tools --- #
ARG REPOFILE=https://raw.githubusercontent.com/Xpra-org/xpra/master/packaging/repos/jammy/xpra.sources
RUN wget -O "/usr/share/keyrings/xpra.asc" https://xpra.org/xpra.asc && \
    cd /etc/apt/sources.list.d && wget $REPOFILE
RUN apt update && apt install -y \
        xpra \
        gdm3 \
        tmux \
        firefox \
        nautilus \
        gnome-shell \
        gnome-session \
        gnome-terminal \
        libqt5x11extras5 \
        xvfb && \
    apt clean

# --- Install python packages --- #
USER ${NB_USER}
RUN pip install --upgrade \
        jupyterlab \
        ipywidgets \
        jupyter-resource-usage \
        jupyter-offlinenotebook \
        jupyter-server-proxy \
        jupyterlab-git && \
    pip cache purge

# --- Install jupyterlab extensions --- #
RUN pip install https://raw.githubusercontent.com/yxzhan/jlab-enhanced-cell-toolbar/main/dist/jlab-enhanced-cell-toolbar-4.0.0.tar.gz
COPY --chown=${NB_USER}:users jupyter-xprahtml5-proxy /home/${NB_USER}/.jupyter-xprahtml5-proxy
RUN pip install -e /home/${NB_USER}/.jupyter-xprahtml5-proxy

WORKDIR /home/${NB_USER}
# --- Appy JupyterLab custom Settings --- #
COPY --chown=${NB_USER}:users ./jupyter-settings.json /opt/conda/share/jupyter/lab/settings/overrides.json

# --- Entrypoint --- #
COPY --chown=${NB_USER}:users entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "start-notebook.sh" ]