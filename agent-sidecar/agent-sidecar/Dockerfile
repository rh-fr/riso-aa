#
# Copyright (c) 2020 ForgeRock AS. Use of this source code is subject to the
# Common Development and Distribution License (CDDL) that can be found in the LICENSE file
#
FROM httpd:2.4

# Install unzip tools for debug
RUN apt-get update && apt-get install -y procps vim unzip

# Enable proxy modules
RUN sed -i 's@#LoadModule proxy_http_module modules/mod_proxy_http.so@LoadModule proxy_http_module modules/mod_proxy_http.so@g' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's@#LoadModule proxy_wstunnel_module modules/mod_proxy_wstunnel.so@LoadModule proxy_wstunnel_module modules/mod_proxy_wstunnel.so@g' /usr/local/apache2/conf/httpd.conf && \
    sed -i 's@#LoadModule proxy_module modules/mod_proxy.so@LoadModule proxy_module modules/mod_proxy.so@g' /usr/local/apache2/conf/httpd.conf 

RUN echo 'ProxyPass / http://localhost:8080/' >> /usr/local/apache2/conf/httpd.conf && \
    echo 'ProxyPassReverse / http://localhost:8080/' >> /usr/local/apache2/conf/httpd.conf

# Change apache owner to daemon
RUN chown -R daemon: /usr/local/apache2 && chmod 773 /usr/local/apache2/logs

# Set permissions for apache logs
RUN chmod 773 /usr/local/apache2/logs

# Copy Apache to machine
COPY Apache_v24_Linux_64bit_5.7.0-SNAPSHOT.zip /opt/agent.zip

# Unzip agent
RUN cd /opt && \
    unzip ./agent.zip && \
    echo "password" > /opt/pwd && \
    rm -rf /opt/agent.zip

# Install Agent
RUN /opt/web_agents/apache24_agent/bin/agentadmin \
    --s \
    "/usr/local/apache2/conf/httpd.conf" \
    "http://am-agent.apps-crc.testing:80/am" \
    "http://my-app-agent.apps-crc.testing:80" \
    "/" \
    "agent" \
    "/opt/pwd" \
    --changeOwner \
    --acceptLicence \
    --forceInstall


#USER daemon
USER root

CMD ["httpd-foreground"]
