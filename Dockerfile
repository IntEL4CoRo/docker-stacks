FROM jupyter/minimal-notebook:ubuntu-20.04

# --- Define Environment Variables--- #
# ARG ROS_PKG=ros-base
ARG ROS_PKG=desktop-full
LABEL version="ROS-noetic-${ROS_PKG}"
ENV ROS_DISTRO=noetic
ENV ROS_PATH=/opt/ros/${ROS_DISTRO}
ENV ROS_ROOT=${ROS_PATH}/share/ros
ENV ROS_WS=/home/${NB_USER}/workspace/ros

# --- Install basic tools --- #
USER root
RUN  apt update && apt install -y \
      git \
      vim \
      curl \
      tmux \
      wget \
      gnupg2 \
      net-tools\
      ca-certificates \
      apt-transport-https \
      build-essential \
      lsb-release \
      gdm3 \
      nautilus \
      gnome-shell \
      gnome-session \
      gnome-terminal \
      libqt5x11extras5 \
      dbus-x11 \
      xfce4 \
      xfce4-panel \
      xfce4-session \
      xfce4-settings \
      xorg \
      xubuntu-icon-theme \
      xvfb

# --- Install VNC server TurboVNC --- #
ENV PATH=/opt/TurboVNC/bin:$PATH
RUN echo "Installing TurboVNC"; \
    # Install instructions from https://turbovnc.org/Downloads/YUM
    wget -q -O- https://packagecloud.io/dcommander/turbovnc/gpgkey | \
    gpg --dearmor >/etc/apt/trusted.gpg.d/TurboVNC.gpg; \
    wget -O /etc/apt/sources.list.d/TurboVNC.list https://raw.githubusercontent.com/TurboVNC/repo/main/TurboVNC.list; \
    apt-get -y -qq update; \
    apt-get -y -qq install \
        turbovnc \
    ; \
    rm -rf /var/lib/apt/lists/*;

USER $NB_USER
RUN conda install -y websockify
ENV DISPLAY=:1

# --- Install Oh-my-bash --- #
USER ${NB_USER}
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
COPY --chown=${NB_USER}:users ./bashrc.sh /home/${NB_USER}/.bashrc

# --- update nodejs version for installing jupyter extensions from source --- #
RUN mamba install -y -q "nodejs>=22"

# --- Install ROS noetic --- #
USER root
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
RUN apt update -q \
  && apt dist-upgrade -y \
  && apt install -y \
      ros-${ROS_DISTRO}-${ROS_PKG} \
      ros-${ROS_DISTRO}-tf2-tools \
  && apt clean \
  && echo "source ${ROS_PATH}/setup.bash" >> /root/.bashrc \
  && echo "source ${ROS_PATH}/setup.bash" >> /home/${NB_USER}/.bashrc

USER ${NB_USER}
# --- Install python packages --- #
SHELL ["conda", "run", "-n", "base", "/bin/bash", "-c"]
RUN pip install \
    autobahn \
    catkin-tools \
    cbor2 \
    cryptography==38.0.4 \
    empy==3.3.4 \
    gnupg \
    ipywidgets \
    jupyterlab~=4.0.0 \
    sidecar \
    jupyter-resource-usage \
    jupyter-offlinenotebook \
    jupyter-server-proxy \
    jupyter-remote-desktop-proxy \
    jupyter-archive \
    jupyterlab_execute_time \
    jupyterlab-language-pack-de-DE \
    service_identity \
    pymongo \
    Pillow \
    pycryptodomex \
    pyyaml==5.3.1 \
    rosdep \
    rosinstall \
    rosinstall-generator \
    rosdistro \
    simplejpeg \
    twisted \
    vcstool \
    wstool \
&& pip cache purge

# --- Install custom jupyterlab extensions --- #
RUN pip install https://raw.githubusercontent.com/yxzhan/jupyterlab-rviz/master/dist/jupyterlab_rviz-0.3.2.tar.gz \
  https://raw.githubusercontent.com/yxzhan/extension-examples/main/cell-toolbar/dist/jupyterlab_examples_cell_toolbar-0.1.4.tar.gz


# --- Install VScode server--- #
# USER root
USER ${NB_USER}
RUN mamba install -y code-server
RUN echo 'alias code="$(which code-server)"' >> ~/.bashrc
RUN code-server --install-extension ms-python.python \
  && code-server --install-extension ms-toolsai.jupyter
RUN pip install -U tornado
RUN pip install git+https://github.com/yxzhan/jupyter-code-server.git

# --- Create a ROS workspace with Robot Web Tools --- #
RUN mkdir -p ${ROS_WS}/src
WORKDIR ${ROS_WS}
USER root
RUN rosdep init
USER ${NB_USER}
RUN catkin init && \
    cd src && \
    wstool init && \
    wstool merge https://raw.githubusercontent.com/yxzhan/rvizweb/master/.rosinstall && \
    wstool update && \
    catkin config --extend ${ROS_PATH}

USER root
RUN apt update && \
    rosdep update --include-eol-distros && \
    rosdep install -y --ignore-src --from-paths ./ -r && \
    rosdep fix-permissions

USER ${NB_USER}
RUN catkin build
RUN echo "source ${ROS_WS}/devel/setup.bash" >> /home/${NB_USER}/.bashrc

USER ${NB_USER}
WORKDIR /home/${NB_USER}

# --- Copy JupyterLab UI settings files --- #
COPY --chown=${NB_USER}:users ./jupyter-settings.json /opt/conda/share/jupyter/lab/settings/overrides.json
COPY --chown=${NB_USER}:users webapps.json ${ROS_WS}/src/rvizweb/webapps/app.json

# --- Entrypoint --- #
COPY --chown=${NB_USER}:users entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
CMD [ "start-notebook.sh" ]