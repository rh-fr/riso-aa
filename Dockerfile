#
# Copyright (c) 2019 ForgeRock AS. Use of this source code is subject to the
# Common Development and Distribution License (CDDL) that can be found in the LICENSE file
#
FROM httpd:2.4

# Copy testing pages to image
COPY web/ /usr/local/apache2/htdocs/

# Set port to 8080
RUN sed -i 's/Listen 80/Listen 8080/g' /usr/local/apache2/conf/httpd.conf 

# Change apache owner to daemon
RUN chown -R daemon: /usr/local/apache2

EXPOSE 8080

USER daemon
