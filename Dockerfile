FROM centos/systemd
LABEL name="habitat"

USER root

ENV HAB_BLDR_URL="https://bldr.habitat.sh"
ENV HAB_LICENSE="accept-no-persist"

RUN curl -s https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.sh | bash &&\
  useradd hab

EXPOSE 9631/tcp
EXPOSE 9632/tcp
EXPOSE 9638/tcp
EXPOSE 9638/udp

COPY hab-sup.service /etc/systemd/system/hab-sup.service
RUN hab pkg install -b core/hab-sup &&\
  ln -s /etc/systemd/system/hab-sup.service /lib/systemd/system/default.target.wants/hab-sup.service

ENTRYPOINT ["/usr/sbin/init"]
