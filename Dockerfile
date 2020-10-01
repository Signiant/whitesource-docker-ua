FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive
ENV JAVA_HOME       /usr/lib/jvm/java-8-openjdk-amd64
ENV PATH 	    	$JAVA_HOME/bin:$PATH
ENV LANGUAGE	en_US.UTF-8
ENV LANG    	en_US.UTF-8
ENV LC_ALL  	en_US.UTF-8

### Install wget, curl, git, unzip, gnupg, locales, rpm
RUN apt-get update && \
	apt-get -y install wget curl git unzip gnupg locales rpm && \
	locale-gen en_US.UTF-8 && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /tmp/*

### add a new group + user without root premmsions
ENV WSS_GROUP wss-group
ENV WSS_USER wss-scanner
ENV WSS_USER_HOME=/home/${WSS_USER}

RUN groupadd ${WSS_GROUP} && \
	useradd --gid ${WSS_GROUP} --groups 0 --shell /bin/bash --home-dir ${WSS_USER_HOME} --create-home ${WSS_USER} && \
	passwd -d ${WSS_USER}


### Install Java openjdk 8
RUN echo "deb http://ppa.launchpad.net/openjdk-r/ppa/ubuntu bionic main" | tee /etc/apt/sources.list.d/ppa_openjdk-r.list && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys DA1A4A13543B466853BAF164EB9B1D8886F44E2A && \
    apt-get update && \
    apt-get -y install openjdk-8-jdk && \
    apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /tmp/*


### Install Maven (3.5.4)
ARG MAVEN_VERSION=3.5.4
ARG SHA=CE50B1C91364CB77EFE3776F756A6D92B76D9038B0A0782F7D53ACF1E997A14D
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref && \
	curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
	echo "${SHA}  /tmp/apache-maven.tar.gz" | sha256sum -c - && \
	tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 && \
	rm -f /tmp/apache-maven.tar.gz && \
	ln -s /usr/share/maven/bin/mvn /usr/bin/mvn && \
	mkdir -p -m 777 ${WSS_USER_HOME}/.m2/repository && \
	chown -R ${WSS_USER}:${WSS_GROUP} ${WSS_USER_HOME}/.m2 && \
	rm -rf /tmp/*

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG ${WSS_USER_HOME}/.m2


### Install Node.js (8.9.4) + NPM (5.6.0)
RUN apt-get update && \
	curl -sL https://deb.nodesource.com/setup_8.x | bash && \
    apt-get install -y nodejs build-essential && \
    apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /tmp/*

### Install Yarn
RUN npm i -g yarn@1.5.1

#### Install Bower + provide premmsions
#RUN npm i -g bower --allow-root && \
#	echo '{ "allow_root": true }' > ${WSS_USER_HOME}/.bowerrc && \
#	chown -R ${WSS_USER}:${WSS_GROUP} ${WSS_USER_HOME}/.bowerrc


### Install Gradle
RUN wget -q https://services.gradle.org/distributions/gradle-6.0.1-bin.zip && \
    unzip gradle-6.0.1-bin.zip -d /opt && \
    rm gradle-6.0.1-bin.zip
### Set Gradle in the environment variables
ENV GRADLE_HOME /opt/gradle-6.0.1
ENV PATH $PATH:/opt/gradle-6.0.1/bin


### Install all the python2.7 + python3.6 packages
RUN apt-get update && \
	apt-get install -y python3-pip python3.6-venv && \
    apt-get install -y python-pip && \
    pip3 install pipenv && \
    apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	rm -rf /tmp/*

# python utilities
RUN python -m pip install --upgrade pip && \
    python3 -m pip install --upgrade pip && \
    python -m pip install virtualenv && \
    python3 -m pip install virtualenv

### optional: python3.8 (used with UA flag: 'python.path')
RUN apt-get update && \
   apt-get install -y python3.8 python3.8-venv && \
   python3.8 -m pip install --upgrade pip && \
   apt-get clean && \
   rm -rf /var/lib/apt/lists/* && \
   rm -rf /tmp/*

#### Install Poetry (python)
#### requires python3.X version matching the projects (defaults to python3.6)
#### sed command sets the default selected python-executable used by poetry to be 'python3'
#ENV POETRY_HOME ${WSS_USER_HOME}/.poetry
#RUN curl -sSLO https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py && \
#	sed -i 's/allowed_executa11bles = \["python", "python3"\]/allowed_executables = \["python3", "python"\]/g' get-poetry.py && \
#	python3 get-poetry.py --yes --version 1.0.5 && \
#	chown -R ${WSS_USER}:${WSS_GROUP} ${WSS_USER_HOME}/.poetry && \
#	rm -rf get-poetry.py
#ENV PATH ${WSS_USER_HOME}/.poetry/bin:${PATH}


### Install GO:
USER ${WSS_USER}
RUN mkdir -p ${WSS_USER_HOME}/goroot && \
   curl https://storage.googleapis.com/golang/go1.12.6.linux-amd64.tar.gz | tar xvzf - -C ${WSS_USER_HOME}/goroot --strip-components=1
## Set GO environment variables
ENV GOROOT ${WSS_USER_HOME}/goroot
ENV GOPATH ${WSS_USER_HOME}/gopath
ENV PATH $GOROOT/bin:$GOPATH/bin:$PATH
## Install package managers
RUN go get -u github.com/golang/dep/cmd/dep
RUN go get github.com/tools/godep
RUN go get github.com/LK4D4/vndr
RUN go get -u github.com/kardianos/govendor
RUN go get -u github.com/gpmgo/gopm
RUN go get github.com/Masterminds/glide
USER root

### Switch User ###
ENV HOME ${WSS_USER_HOME}
WORKDIR ${WSS_USER_HOME}
USER ${WSS_USER}

### copy data to the image
# COPY wss wss
# COPY <data-dir> Data
RUN mkdir wss && \
    cd wss && \
    curl -LJO https://github.com/whitesource/unified-agent-distribution/releases/latest/download/wss-unified-agent.jar && \
    curl -LJO https://github.com/whitesource/unified-agent-distribution/raw/master/standAlone/wss-unified-agent.config

### base command
CMD java -jar ./wss/wss-unified-agent.jar -c ./wss/wss-unified-agent.config -d ./Data`
