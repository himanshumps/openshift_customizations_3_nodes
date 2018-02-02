FROM docker.elastic.co/elasticsearch/elasticsearch:5.6.2
ENV http.host 0.0.0.0
ENV xpack.security.enabled false
USER root
RUN chgrp -R 0 /usr/share/elasticsearch && \
    chmod -Rf g+rwx /usr/share/elasticsearch
USER elasticsearch