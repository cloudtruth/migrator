FROM ruby:3.0-alpine AS base

ENV APP_DIR="/srv/app" \
    BUNDLE_PATH="/srv/bundler" \
    BUILD_PACKAGES="build-base ruby-dev" \
    APP_PACKAGES="bash tzdata shared-mime-info" \
    APP_USER="app" \
    CT_CLI_EXPORT_VER="1.2.0" \
    CT_CLI_IMPORT_VER="1.2.0"

ENV CT_CLI_EXPORT_BINARY="/usr/local/bin/cloudtruth-${CT_CLI_EXPORT_VER}" \
    CT_CLI_IMPORT_BINARY="/usr/local/bin/cloudtruth-${CT_CLI_IMPORT_VER}"

# Thes env var definitions reference values from the previous definitions, so
# they need to be split off on their own. Otherwise, they'll receive stale
# values because Docker will read the values once before it starts setting
# values.
ENV BUNDLE_BIN="${BUNDLE_PATH}/bin" \
    BUNDLE_APP_CONFIG="${BUNDLE_PATH}" \
    GEM_HOME="${BUNDLE_PATH}" \
    RELEASE_PACKAGES="${APP_PACKAGES}"

ENV PATH="${APP_DIR}:${APP_DIR}/bin:${BUNDLE_BIN}:${PATH}"

RUN mkdir -p $APP_DIR $BUNDLE_PATH
WORKDIR $APP_DIR

FROM base as build

RUN apk add --no-cache \
    --virtual app \
    $APP_PACKAGES && \
  apk add --no-cache \
    --virtual build_deps \
    $BUILD_PACKAGES

RUN wget -qO- https://github.com/cloudtruth/cloudtruth-cli/releases/latest/download/install.sh |  sh -s -- -v $CT_CLI_EXPORT_VER
RUN mv /usr/local/bin/cloudtruth /usr/local/bin/cloudtruth-${CT_CLI_EXPORT_VER}
RUN wget -qO- https://github.com/cloudtruth/cloudtruth-cli/releases/latest/download/install.sh |  sh -s -- -v $CT_CLI_IMPORT_VER
RUN mv /usr/local/bin/cloudtruth /usr/local/bin/cloudtruth-${CT_CLI_IMPORT_VER}

COPY Gemfile* $APP_DIR/
RUN bundle install --jobs=4

COPY . $APP_DIR/

ENTRYPOINT ["bundle", "exec", "cloudtruth-migrator"]
CMD ["--help"]
