FROM ubuntu:trusty

ENV DEBIAN_FRONTEND noninteractive
ENV GDAL_PATH /usr/share/gdal
ENV GEOSERVER_HOME /opt/geoserver
ENV JAVA_HOME /usr
ENV JAVA_OPTS "-Xms2g -Xmx2g"
ENV GDAL_DATA $GDAL_PATH/1.10
ENV PATH $GDAL_PATH:$PATH
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/usr/lib/jni:/usr/share/java
ENV BADGER_VERSION 0.5.0

RUN export DEBIAN_FRONTEND=noninteractive
RUN dpkg-divert --local --rename --add /sbin/initctl

# Install packages
RUN \
  apt-get -y update --fix-missing && \
  apt-get -y install unzip software-properties-common xmlstarlet && apt-get install -y libssl-dev libffi-dev python-dev python-pip && \
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get -y update && \
  apt-get install -y oracle-java8-installer gdal-bin libgdal-java && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk8-installer && \
  rm -rf /tmp/* /var/tmp/*

ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# Get native JAI and ImageIO
RUN \
    cd $JAVA_HOME && \
    wget http://data.boundlessgeo.com/suite/jai/jai-1_1_3-lib-linux-amd64-jdk.bin && \
    echo "yes" | sh jai-1_1_3-lib-linux-amd64-jdk.bin && \
    rm jai-1_1_3-lib-linux-amd64-jdk.bin

RUN \
    cd $JAVA_HOME && \
    export _POSIX2_VERSION=199209 &&\
    wget http://data.opengeo.org/suite/jai/jai_imageio-1_1-lib-linux-amd64-jdk.bin && \
    echo "yes" | sh jai_imageio-1_1-lib-linux-amd64-jdk.bin && \
    rm jai_imageio-1_1-lib-linux-amd64-jdk.bin

#
# GEOSERVER INSTALLATION
#
ENV GEOSERVER_VERSION 2.11.0

# Get GeoServer
RUN wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/geoserver-$GEOSERVER_VERSION-bin.zip -O ~/geoserver.zip &&\
    unzip ~/geoserver.zip -d /opt && mv -v /opt/geoserver* /opt/geoserver && \
    rm ~/geoserver.zip

# Get OGR plugin
RUN wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/extensions/geoserver-$GEOSERVER_VERSION-ogr-wfs-plugin.zip -O ~/geoserver-ogr-plugin.zip &&\
    unzip -o ~/geoserver-ogr-plugin.zip -d /opt/geoserver/webapps/geoserver/WEB-INF/lib/ && \
    rm ~/geoserver-ogr-plugin.zip

# Get GDAL plugin
RUN wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/extensions/geoserver-$GEOSERVER_VERSION-gdal-plugin.zip -O ~/geoserver-gdal-plugin.zip &&\
    unzip -o ~/geoserver-gdal-plugin.zip -d /opt/geoserver/webapps/geoserver/WEB-INF/lib/ && \
    rm ~/geoserver-gdal-plugin.zip

# Get printing plugin
RUN wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/extensions/geoserver-$GEOSERVER_VERSION-printing-plugin.zip -O ~/geoserver-printing-plugin.zip &&\
    unzip ~/geoserver-printing-plugin.zip -d /opt/geoserver/webapps/geoserver/WEB-INF/lib/ && \
    rm ~/geoserver-printing-plugin.zip

# Get import plugin
RUN wget -c http://downloads.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/extensions/geoserver-$GEOSERVER_VERSION-importer-plugin.zip -O ~/geoserver-importer-plugin.zip &&\
    unzip -o ~/geoserver-importer-plugin.zip -d /opt/geoserver/webapps/geoserver/WEB-INF/lib/ && \
    rm ~/geoserver-importer-plugin.zip

# Replace GDAL Java bindings
RUN rm -rf $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/imageio-ext-gdal-bindings-1.9.2.jar
RUN cp /usr/share/java/gdal.jar $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/gdal.jar

# Remove old JAI from geoserver
RUN rm -rf $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/jai_codec-1.1.3.jar && \
    rm -rf $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/jai_core-1.1.3.jar && \
    rm -rf $GEOSERVER_HOME/webapps/geoserver/WEB-INF/lib/jai_imageio-1.1.jar

COPY default_point.sld $GEOSERVER_HOME/data_dir/styles
COPY sample_workspace $GEOSERVER_HOME/data_dir/workspaces

ENV DATASTORE_PATH "$GEOSERVER_HOME/data_dir/workspaces/gdb/gdb/datastore.xml"

# Install badger for config resolution
RUN wget -O /usr/src/badger.tar.gz https://git.axonvibelabs.com/devops/badger/repository/archive.tar.gz?ref=$BADGER_VERSION \
    && tar xvzf /usr/src/badger.tar.gz -C /usr/src/ \
    && mv /usr/src/badger-$BADGER_VERSION-* /usr/src/badger \
    && rm /usr/src/badger.tar.gz


# # Database setting in datastore file
# RUN if [ ! -z "$GEOSERVER_CONFIG_FILE" ] ; then wget -q $GEOSERVER_CONFIG_FILE -O $GEOSERVER_HOME/data_dir/workspaces/gdb/gdb/datastore.xml ; fi

# # Database setting manual config
# RUN if [ ! -z "$DATABASE_SCHEMA" ] ; then xmlstarlet ed --inplace -u '/dataStore/connectionParameters/entry[@key="schema"]' -v $DATABASE_SCHEMA $DATASTORE_PATH ; fi
# RUN if [ ! -z "$DATABASE_NAME" ] ; then xmlstarlet ed --inplace -u '/dataStore/connectionParameters/entry[@key="database"]' -v $DATABASE_NAME $DATASTORE_PATH ; fi
# RUN if [ ! -z "$DATABASE_PORT" ] ; then xmlstarlet ed --inplace -u '/dataStore/connectionParameters/entry[@key="port"]' -v $DATABASE_PORT $DATASTORE_PATH ; fi
# RUN if [ ! -z "$DATABASE_USER" ] ; then xmlstarlet ed --inplace -u '/dataStore/connectionParameters/entry[@key="user"]' -v $DATABASE_USER $DATASTORE_PATH ; fi
# RUN if [ ! -z "$DATABASE_PASSWORD" ] ; then xmlstarlet ed --inplace -u '/dataStore/connectionParameters/entry[@key="passwd"]' -v $DATABASE_PASSWORD $DATASTORE_PATH ; fi
# RUN if [ ! -z "$DATABASE_HOST" ] ; then xmlstarlet ed --inplace -u '/dataStore/connectionParameters/entry[@key="host"]' -v $DATABASE_HOST $DATASTORE_PATH ; fi
# RUN if [ ! -z "$GEOSERVER_MAX_CONNECTION" ] ; then xmlstarlet ed --inplace -u '/dataStore/connectionParameters/entry[@key="max connections"]' -v $GEOSERVER_MAX_CONNECTION $DATASTORE_PATH ; fi

# Needed for config resolution for service & secrets lookups
RUN pip install Jinja2 credstash validators


ENV USER 1001
RUN chown -R 1001:0 "$GEOSERVER_HOME" && chmod -R ug+rwx "$GEOSERVER_HOME"
USER 1001

# Expose GeoServer's default port
EXPOSE 8080
CMD  python /usr/src/badger/bin/fetch_config.py   $DATASTORE_PATH; /opt/geoserver/bin/startup.sh
