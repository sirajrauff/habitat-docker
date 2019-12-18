FROM centos/systemd
LABEL name="habitat"

USER root

ENV HAB_BLDR_URL="https://bldr.habitat.sh"
ENV HAB_LICENSE="accept-no-persist"

RUN curl https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.sh | bash &&\
 useradd hab

EXPOSE 9631/tcp
EXPOSE 9632/tcp
EXPOSE 9638/tcp
EXPOSE 9638/udp

RUN curl https://gist.githubusercontent.com/sirajrauff/761a29036f7a54fa977cbbc1d4749523/raw/7f93d5e8cd59925f6e447c533f9c29d1d75f48ea/hab-sup.service > /etc/systemd/system/hab-sup.service &&\
    hab pkg install -b core/hab-sup &&\
    ln -s /etc/systemd/system/hab-sup.service /lib/systemd/system/default.target.wants/hab-sup.service

ENTRYPOINT ["/usr/sbin/init"]
