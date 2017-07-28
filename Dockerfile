FROM ubuntu:16.10
MAINTAINER gyao

ENV SPARK_PROFILE 2.1
ENV SPARK_VERSION 2.1.1
ENV HADOOP_PROFILE 2.7
ENV HADOOP_VERSION 2.7.0
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

ENV LOG_TAG="[GYAO_DS_BOX]:"

##########################################
# Update and install basic packages
##########################################
RUN echo "$LOG_TAG update and install basic packages"
RUN apt-get -y update
RUN apt-get install -y locales
RUN locale-gen $LANG
RUN apt-get install -y software-properties-common
RUN apt -y autoclean
RUN apt -y dist-upgrade
RUN apt-get install -y build-essential rsync curl grep sed dpkg openssh-server openssh-client vim nfs-common


##########################################
# Install tini
##########################################
RUN echo "$LOG_TAG install tini related packages" \
    && TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` \
    && curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb \
    && dpkg -i tini.deb \
    && rm tini.deb


##########################################
# Install Java
##########################################
ENV JAVA_HOME=/usr/lib/jvm/java-8-oracle
RUN echo "$LOG_TAG Install java8"
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
RUN add-apt-repository -y ppa:webupd8team/java
RUN apt-get -y update
RUN apt-get install -y oracle-java8-installer
RUN rm -rf /var/lib/apt/lists/*
RUN rm -rf /var/cache/oracle-jdk8-installer


##########################################
# Install Hadoop
##########################################
RUN mkdir -p /data/hdfs-nfs/
RUN mkdir -p /opt
WORKDIR /opt

# Install
RUN curl -L -s https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz -s -o - | tar -xzf -
RUN mv hadoop-$HADOOP_VERSION hadoop

# Setup
WORKDIR /opt/hadoop
ENV PATH /opt/hadoop/bin:/opt/hadoop/sbin:$PATH
RUN sed --in-place='.ori' -e "s/\${JAVA_HOME}/\/usr\/lib\/jvm\/java-8-oracle/" etc/hadoop/hadoop-env.sh

# Configure ssh client
RUN ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa
RUN cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
RUN chmod 0600 /root/.ssh/authorized_keys

RUN echo "\nHost *\n" >> /root/.ssh/config && \
    echo "   StrictHostKeyChecking no\n" >> /root/.ssh/config && \
    echo "   UserKnownHostsFile=/dev/null\n" >> /root/.ssh/config

# Disable sshd authentication
RUN echo "root:root" | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
# => Quick fix for enabling datanode connections
#    ssh -L 50010:localhost:50010 root@192.168.99.100 -p 22022 -o PreferredAuthentications=password

# Pseudo-Distributed Operation
COPY etc/hadoop/core-site.xml etc/hadoop/core-site.xml
COPY etc/hadoop/hdfs-site.xml etc/hadoop/hdfs-site.xml
COPY etc/hadoop/mapred-site.xml etc/hadoop/mapred-site.xml
COPY etc/hadoop/yarn-site.xml etc/hadoop/yarn-site.xml
RUN hdfs namenode -format

# Env
ENV HADOOP_PREFIX /opt/hadoop
ENV HADOOP_COMMON_HOME /opt/hadoop
ENV HADOOP_HDFS_HOME /opt/hadoop
ENV HADOOP_MAPRED_HOME /opt/hadoop
ENV HADOOP_YARN_HOME /opt/hadoop
ENV HADOOP_CONF_DIR /opt/hadoop/etc/hadoop

##########################################
# Install Spark
##########################################
RUN curl -s http://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop$HADOOP_PROFILE.tgz | tar -xz -C /opt/
RUN cd /opt && ln -s spark-$SPARK_VERSION-bin-hadoop$HADOOP_PROFILE spark
ENV SPARK_HOME /opt/spark

ENV YARN_CONF_DIR $HADOOP_PREFIX/etc/hadoop
ENV PATH $PATH:$SPARK_HOME/bin:$HADOOP_PREFIX/bin


##########################################
# Install Python/Anaconda
##########################################
RUN echo "$LOG_TAG Install miniconda2 related packages" && \
    apt-get -y update && \
    apt-get install -y bzip2 ca-certificates \
    libglib2.0-0 libxext6 libsm6 libxrender1 \
    git mercurial subversion && \
    echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda2-4.3.11-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh
ENV PATH /opt/conda/bin:$PATH

RUN echo "$LOG_TAG Install python related packages" && \
    apt-get -y update && \
    apt-get install -y python-dev python-pip && \
    apt-get install -y gfortran && \
    # numerical/algebra packages
    apt-get install -y libblas-dev libatlas-dev liblapack-dev && \
    # font, image for matplotlib
    apt-get install -y libpng-dev libfreetype6-dev libxft-dev && \
    # for tkinter
    apt-get install -y python-tk libxml2-dev libxslt-dev zlib1g-dev && \
    pip install numpy && \
    pip install matplotlib


##########################################
# Expose R/RStudio Server
##########################################
RUN echo "$LOG_TAG Install R related packages" && \
    echo "deb http://cran.rstudio.com/bin/linux/ubuntu yakkety/" | tee -a /etc/apt/sources.list && \
    gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9 && \
    gpg -a --export E084DAB9 | apt-key add - && \
    apt-get -y update && \
    apt-get -y install r-base r-base-dev && \
    R -e "install.packages('dpylr', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('knitr', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('ggplot2', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('googleVis', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('data.table', repos='http://cran.us.r-project.org')" && \
    # for devtools, Rcpp
    apt-get -y install libcurl4-gnutls-dev libssl-dev && \
    R -e "install.packages('devtools', repos='http://cran.us.r-project.org')" && \
    R -e "install.packages('Rcpp', repos='http://cran.us.r-project.org')" && \
    Rscript -e "library('devtools'); library('Rcpp'); install_github('ramnathv/rCharts')"
RUN apt-get -y install gdebi-core
WORKDIR /opt
RUN wget https://download2.rstudio.org/rstudio-server-1.0.153-amd64.deb
RUN yes | gdebi rstudio-server-1.0.153-amd64.deb
RUN echo "server-app-armor-enabled=0" >> /etc/rstudio/rserver.conf
RUN echo "auth-minimum-user-id=0" >> /etc/rstudio/rserver.conf
RUN apt-get -y install apparmor
RUN mkdir -p /etc/apparmor.d/disable/
RUN ln -s /etc/apparmor.d/rstudio-server /etc/apparmor.d/disable/
#RUN apparmor_parser -R /etc/apparmor.d/rstudio-server


##########################################
# Expose Ports
##########################################
# ssh
EXPOSE 22
# hdfs://localhost:8020
EXPOSE 8020
# hdfs namenode
EXPOSE 50020
# hdfs Web browser
EXPOSE 50070
# hdfs datanodes
EXPOSE 50075
# hdfs secondary namenode
EXPOSE 50090
# Mapred ports
EXPOSE 9001
# yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
# spark
EXPOSE 8080 7077 8888 8081 18080
# RStudio
EXPOSE 8787


##########################################
# Boot script
##########################################
COPY entrypoint.sh /etc/entrypoint.sh
RUN chown root.root /etc/entrypoint.sh
RUN chmod 700 /etc/entrypoint.sh


ENTRYPOINT [ "/etc/entrypoint.sh", "/usr/bin/tini", "--" ]
CMD bash
