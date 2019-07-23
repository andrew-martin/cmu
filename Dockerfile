# https://github.com/Mogtofu33/drupal8ci
# https://hub.docker.com/r/juampynr/drupal8ci/~/dockerfile/
# https://github.com/docker-library/drupal/blob/master/8.7/apache/Dockerfile
FROM drupal:8.7-apache

# Install composer.
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Remove the vanilla Drupal project that comes with this image.
RUN rm -rf ..?* .[!.]* *

# Install needed programs for next steps.
RUN apt-get update && apt-get install --no-install-recommends -y \
  apt-transport-https \
  gnupg2 \
  software-properties-common \
  sudo \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Nodejs programs for next steps and php extensions.
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
  && apt-get update && apt-get install --no-install-recommends -y \
  nodejs \
  chromium \
  imagemagick \
  libmagickwand-dev \
  libnss3-dev \
  libxslt-dev \
  mariadb-client \
  jq \
  shellcheck \
  git \
  unzip \
  && curl -fsSL https://github.com/mikefarah/yq/releases/download/2.4.0/yq_linux_amd64 -o /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq \
  # Install xsl, mysqli, xdebug, imagick.
  && docker-php-ext-install xsl mysqli \
  && pecl install imagick xdebug \
  && docker-php-ext-enable imagick xdebug \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /var/www/.composer /var/www/.node \
  && chmod 777 /var/www

WORKDIR /var/www/.composer

# Put a turbo on composer, install phpqa + tools + Robo + Coder.
# Install Drupal dev third party and upgrade Php-unit.
COPY composer.json /var/www/.composer/composer.json
RUN composer install --no-ansi -n --profile --no-suggest \
  && ln -sf /var/www/.composer/vendor/bin/* /usr/local/bin \
  && mkdir -p /var/www/html/vendor/bin/ \
  && ln -sf /var/www/.composer/vendor/bin/* /var/www/html/vendor/bin/ \
  && composer clear-cache \
  && rm -rf /var/www/.composer/cache/*


# Remove Apache logs to stdout from the php image (used by Drupal image).
RUN rm -f /var/log/apache2/access.log \
  && chown -R www-data:www-data /var/www/.composer /var/www/.node

# Fix PHP performance issues.
RUN mv /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini \
  && sed -i "s#memory_limit = 128M#memory_limit = 512M#g" /usr/local/etc/php/php.ini \
  && sed -i "s#max_execution_time = 30#max_execution_time = 90#g" /usr/local/etc/php/php.ini \
  && sed -i "s#;max_input_nesting_level = 64#max_input_nesting_level = 512#g" /usr/local/etc/php/php.ini

# Add Selenium
ENV JAVA_OPTS="-Xmx512m"
ENV SE_OPTS=""
ENV CHROMIUM_OPTS="--no-sandbox --disable-gpu --headless --remote-debugging-address=0.0.0.0 --remote-debugging-port=9222"


ADD http://selenium-release.storage.googleapis.com/3.141/selenium-server-standalone-3.141.59.jar selenium-server-standalone.jar
ADD https://raw.githubusercontent.com/SeleniumHQ/docker-selenium/master/Standalone/start-selenium-standalone.sh /scripts/start-selenium-standalone.sh

RUN mkdir -p /opt/selenium \
  && mv selenium-server-standalone.jar /opt/selenium/ \
  && mkdir -p /usr/share/man/man1 \
  && apt-get update && apt-get install --no-install-recommends -y \
  openjdk-8-jdk \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


EXPOSE 80 4444 9515 9222