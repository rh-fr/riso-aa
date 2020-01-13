# Copyright (c) 2019 ForgeRock AS. Use of this source code is subject to the
# Common Development and Distribution License (CDDL) that can be found in the LICENSE file

FROM tomcat:9-jdk8-openjdk

# Install vim, net-tools, procps
#RUN apt-get update && apt-get install --no-install-recommends -y vim net-tools procps

# Deploy AM
COPY am.war /usr/local/tomcat/webapps/am.war

# Copy docker-entrypoint to image and make it executable
COPY docker-entrypoint.sh /opt/docker-entrypoint.sh
RUN chmod a+x /opt/docker-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["bash", "/opt/docker-entrypoint.sh"]