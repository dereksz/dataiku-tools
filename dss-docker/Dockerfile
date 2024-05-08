# Force amd64 as this is all DataIku supports
FROM --platform=linux/amd64 almalinux:8
# FROM --platform=linux/amd64 almalinux:8

ARG dssVersion=11.2.0

ENV DSS_VERSION="$dssVersion" \
    DSS_DATADIR="/home/dataiku/dss" \
    DSS_PORT=10000

# Dataiku account and data dir setup
RUN useradd dataiku \
    && mkdir -p /home/dataiku ${DSS_DATADIR} \
    && chown -Rh dataiku:dataiku /home/dataiku ${DSS_DATADIR}


RUN find /etc/pki/ca-trust/ -ls

# Set up certificates
ENV CERTCERT_DIR=/etc/pki/ca-trust/source/anchors
COPY certs/certs.pem certs/cert-*.crt ${CERTCERT_DIR}/
RUN chmod 0644 ${CERTCERT_DIR}/* \
    && update-ca-trust force-enable \
    && update-ca-trust extract
# ENV CURL_CA_BUNDLE=${CERTCERT_DIR}/certs.pem

# ARG YUM_OPTS="-y --setopt sslverify=false"
ARG YUM_OPTS="-y"
RUN yum install ${YUM_OPTS} openssl && yum update ${YUM_OPTS}
RUN awk -v cmd='openssl x509 -noout -subject' ' \
        /BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-bundle.crt

# System dependencies
# RUN yum install --help

RUN yum install ${YUM_OPTS} epel-release \
    && yum install ${YUM_OPTS} --enablerepo=powertools \
        glibc-langpack-en \
        file \
        acl \
        expat \
        git \
        nginx \
        unzip \
        zip \
        ncurses-compat-libs \
        java-1.8.0-openjdk \
        python2 \
        python36 \
        freetype \
        libgfortran \
        libgomp \
        R-core-devel \
        libicu-devel \
        libcurl-devel \
        openssl-devel \
        libxml2-devel \
        npm \
        gtk3 \
        libXScrnSaver \
        alsa-lib \
        nss \
        mesa-libgbm \
        libX11-xcb \
        python2-devel \
        python36-devel \
    && yum clean all

RUN ls ${CERTCERT_DIR}/
RUN echo CURL_CA_BUNDLE=${CURL_CA_BUNDLE}


WORKDIR /home/dataiku

# I had the curl working, and then if failes again
# Download and extract DSS kit
ENV DSSKIT="dataiku-dss-$DSS_VERSION"
ADD "https://cdn.downloads.dataiku.com/public/studio/$DSS_VERSION/$DSSKIT.tar.gz" ./
RUN tar xf "$DSSKIT.tar.gz" && rm "$DSSKIT.tar.gz"

# RUN find /home/dataiku/$DSSKIT -name \*.sh
# RUN ls -lath /home/dataiku/$DSSKIT/scripts/install/installdir-postinstall.sh
ENV MAKEFLAGS = -j6
RUN "$DSSKIT"/scripts/install/installdir-postinstall.sh "$DSSKIT" \
    && (cd "$DSSKIT"/resources/graphics-export && npm install puppeteer@13.7.0 fs) \
    && chown -Rh dataiku:dataiku "$DSSKIT"

# Install required R packages
RUN mkdir -p /usr/local/lib/R/site-library \
    && R --slave --no-restore \
        -e "install.packages( \
            c('httr', 'RJSONIO', 'dplyr', 'curl', 'IRkernel', 'sparklyr', 'ggplot2', 'gtools', 'tidyr', \
            'rmarkdown', 'base64enc', 'filelock'), \
            '/usr/local/lib/R/site-library', \
            repos='https://cloud.r-project.org')"

# Entry point
USER dataiku

RUN awk -v cmd='openssl x509 -noout -subject' ' \
        /BEGIN/{close(cmd)};{print | cmd}' < /etc/ssl/certs/ca-bundle.crt

RUN openssl s_client -showcerts -connect mirrors.kernel.org:443

COPY run.sh setup.sh /home/dataiku/


# Trying to get the install to run
ENV DSS_INSTALLDIR="/home/dataiku/dataiku-dss-$DSS_VERSION"
RUN	"$DSS_INSTALLDIR"/installer.sh -d "$DSS_DATADIR" -p "$DSS_PORT"
RUN R --version
RUN	"$DSS_DATADIR"/bin/dssadmin install-graphics-export
RUN	echo "dku.registration.channel=docker-image" >>"$DSS_DATADIR"/config/dip.properties \
    && echo "dku.exports.chrome.sandbox=false" >>"$DSS_DATADIR"/config/dip.properties

# RUN "$DSS_DATADIR"/bin/dssadmin install-R-integration

EXPOSE $DSS_PORT


CMD [ "./run.sh" ]
