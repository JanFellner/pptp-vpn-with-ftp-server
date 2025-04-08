FROM debian:bullseye

RUN apt-get update && \
    apt-get install -y pptpd vsftpd iproute2 iptables && \
    mkdir -p /etc/ppp /var/run/pptpd /var/ftp/upload

# Nur Startscript ins Image kopieren
COPY start.sh /start.sh
RUN chmod +x /start.sh

VOLUME ["/config", "/var/ftp/upload"]

CMD ["/start.sh"]