#
# Copyright (c) 2019 ForgeRock AS. Use of this source code is subject to the
# Common Development and Distribution License (CDDL) that can be found in the LICENSE file
#
FROM httpd:2.4

# Copy testing pages to image
COPY web/ /usr/local/apache2/htdocs/

USER root

