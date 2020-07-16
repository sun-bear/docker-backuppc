FROM tiredofit/nginx:alpine-3.12
# FROM tiredofit/nginx:alpine-3.11 - 3.1.3beta1 - 3.1.2.2
LABEL maintainer="sun-bear"

ENV BACKUPPC_VERSION=4.4.0 \
    BACKUPPC_XS_VERSION=0.62 \
    PAR2_VERSION=v0.8.1 \
    RSYNC_BPC_VERSION=3.1.3beta1 \
	RESET_PERMISSIONS=TRUE \
    NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    ENABLE_SMTP=FALSE \
    NGINX_USER=backuppc \
    NGINX_GROUP=backuppc \
    ENABLE_ZABBIX=FALSE \
	HOST_KEY=/home/backuppc/.ssh/host_key \
	AUTHORIZED_KEYS_FILE=/var/lib/backuppc/.ssh/authorized_keys \
	ZABBIX_HOSTNAME=backuppc-app
	
# CMD ["bash", "-c", "/usr/sbin/sshd -f /rrsync/sshd_config -h $HOST_KEY -o AuthorizedKeysFile=$AUTHORIZED_KEYS_FILE -D"]

# # INSTALL BACKUPPC BUILD DEPENDENCIES
RUN \
	set -x && \
    apk update && \
    apk upgrade && \
	echo "**** INSTALL BUILD DEPENDENCIES ****" && \
    apk add -t .backuppc-build-deps \
        autoconf \
        automake \
        acl-dev \
        build-base \
        bzip2-dev \
        expat-dev \
        g++ \
        gcc \
        git \
        make \
        patch \
        perl-dev \
        curl && \
# # INSTALL BACKUPPC RUNTIME DEPENDENCIES
	echo "**** INSTALL RUNTIME DEPENDENCIES ****" && \
    apk add -t .backuppc-run-deps \
        bzip2 \
        expat \
        gzip \
        fcgiwrap \
        iputils \
        openssh \
        openssl \
        perl \
        perl-archive-zip \
        perl-cgi \
        perl-file-listing \
        perl-xml-rss \
        pigz \
        rrdtool \
        rsync \
        samba-client \
        spawn-fcgi \
        sudo \
        ttf-dejavu \
        tar \
        bash \
        git \
        supervisor \
        curl \
        msmtp \
        net-tools \
        htop \
        nano \
        vim \
        ssmtp

# # COMPILE AND INSTALL PARALLEL BZIP
RUN \
	echo "**** COMPILE AND INSTALL PARALLEL BZIP ****" && \
	mkdir -p /usr/src/pbzip2 && \
    curl -ssL https://launchpad.net/pbzip2/1.1/1.1.13/+download/pbzip2-1.1.13.tar.gz | tar x -vz -f - --strip=1 -C /usr/src/pbzip2 && \
    cd /usr/src/pbzip2 && \
    make && \
    make install

# # COMPILE AND INSTALL BackupPC:XS
RUN \
	echo "**** COMPILE AND INSTALL BackupPC:XS ****" && \
	cd /usr/src && \
    git clone https://github.com/backuppc/backuppc-xs.git /usr/src/backuppc-xs --branch $BACKUPPC_XS_VERSION && \
    cd /usr/src/backuppc-xs && \
    perl Makefile.PL && \
    make && \
    make test && \
    make install

# # COMPILE AND INSTALL Rsync (BPC VERSION)
RUN \
	echo "**** COMPILE AND INSTALL Rsync (BPC VERSION) ****" && \
	git clone https://github.com/backuppc/rsync-bpc.git /usr/src/rsync-bpc --branch $RSYNC_BPC_VERSION && \
	cp -Rpfv /usr/src/rsync-bpc/support/rrsync /usr/local/bin/ && \
	chmod +x /usr/local/bin/rrsync && \
    cd /usr/src/rsync-bpc && \
    ./configure && \
    make reconfigure && \
    make && \
    make install

# # COMPILE AND INSTALL PAR2
RUN \
	echo "**** COMPILE AND INSTALL PAR2 ****" && \
	git clone https://github.com/Parchive/par2cmdline.git /usr/src/par2cmdline --branch $PAR2_VERSION && \
    cd /usr/src/par2cmdline && \
    ./automake.sh && \
    ./configure && \
    make && \
    make check && \
    make install

# # Get BackupPC, it will be installed at runtime to allow dynamic upgrade of existing config/pool
RUN \
	echo "**** COMPILE AND EXTRACT BackupPC ****" && \
	mkdir -p /usr/src/BackupPC && \
	curl -ssL https://github.com/backuppc/backuppc/releases/download/$BACKUPPC_VERSION/BackupPC-$BACKUPPC_VERSION.tar.gz | tar x -vz -f - --strip=1 -C /usr/local/BackupPC && \
	# curl -o /usr/src/BackupPC-$BACKUPPC_VERSION.tar.gz -L https://github.com/backuppc/backuppc/releases/download/$BACKUPPC_VERSION/BackupPC-$BACKUPPC_VERSION.tar.gz | tar x -vz -f /usr/src/BackupPC-$BACKUPPC_VERSION.tar.gz --strip=1 -C /usr/src/BackupPC && \
	# rm -rf /usr/src/BackupPC-$BACKUPPC_VERSION.tar.gz && \
    cp -Rpfv /usr/local/BackupPC /usr/src/BackupPC && \
	\
    # # Prepare backuppc home
    mkdir -p /home/backuppc && \
    \
    # # Mark the docker as not runned yet, to allow entrypoint to do its stuff
    touch /firstrun && \
    \
    # # CLEANUP
	echo "**** CLEANUP ****" && \
    apk del .backuppc-build-deps && \
    # rm -rf /usr/src/backuppc-xs /usr/src/rsync-bpc /usr/src/par2cmdline /usr/src/pbzip2 /usr/src/BackupPC && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

# ### Add Folders
ADD install/ /

# ## Zabbix Setup 
# RUN chmod +x /etc/zabbix/zabbix_agentd.conf.d/*.pl

# ## Networking
EXPOSE 80 22
