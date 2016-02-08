FROM sameersbn/ubuntu:14.04.20160121
MAINTAINER sameer@damagehead.com

ENV PG_APP_HOME="/etc/docker-postgresql"\
    PG_VERSION=9.4 \
    PG_USER=postgres \
    PG_HOME=/var/lib/postgresql \
    PG_RUNDIR=/run/postgresql \
    PG_LOGDIR=/var/log/postgresql \
    PG_CERTDIR=/etc/postgresql/certs

ENV PG_BINDIR=/usr/lib/postgresql/${PG_VERSION}/bin \
    PG_DATADIR=${PG_HOME}/${PG_VERSION}/main

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo 'deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y acl \
      postgresql-${PG_VERSION} postgresql-client-${PG_VERSION} postgresql-contrib-${PG_VERSION} \
 && ln -sf ${PG_DATADIR}/postgresql.conf /etc/postgresql/${PG_VERSION}/main/postgresql.conf \
 && ln -sf ${PG_DATADIR}/pg_hba.conf /etc/postgresql/${PG_VERSION}/main/pg_hba.conf \
 && ln -sf ${PG_DATADIR}/pg_ident.conf /etc/postgresql/${PG_VERSION}/main/pg_ident.conf \
 && rm -rf ${PG_HOME}

COPY runtime/ ${PG_APP_HOME}/
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod 755 /sbin/entrypoint.sh

EXPOSE 5432/tcp
VOLUME ["${PG_HOME}", "${PG_RUNDIR}"]
WORKDIR ${PG_HOME}
#ENTRYPOINT ["/sbin/entrypoint.sh"]

## SSH
RUN apt-get install -y openssh-server && \
    sed -i \
    -e 's/^UsePAM yes/#UsePAM yes/' \
    -e 's/PermitRootLogin without-password/PermitRootLogin yes/' \
    /etc/ssh/sshd_config && \
    mkdir -p /var/run/sshd && \
    sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd && \
    echo 'root:root27' | chpasswd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile
EXPOSE 22

## Supervisor
RUN apt-get install -y supervisor \
    && mkdir -p /var/log/supervisor \
    && chmod -R 777 /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

## MISC
RUN apt-get install -y vim perl

## CLEAN UP
RUN rm -rf /var/lib/apt/lists/*

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisor/conf.d/supervisord.conf", "--pidfile=/var/run/supervisord.pid"]
