FROM rocker/r2u:22.04

WORKDIR /workspace

ENV RENV_CONFIG_PAK_ENABLED=TRUE
ENV RENV_PATHS_CACHE="/renv/cache"

RUN apt-get update && apt-get -y install curl && curl -Ls https://github.com/r-lib/rig/releases/download/latest/rig-linux-$(arch)-latest.tar.gz | tar xz -C /usr/local && rig add 4.2.0 && rig system add-pak && mkdir -p /renv/cache
RUN rig run -r 4.2.0 -e "pak::pak('renv')"
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R
COPY renv/settings.json renv/settings.json
RUN rig run -r 4.2.0 -e "renv::restore()"

EXPOSE 5543

COPY app.R app.R
COPY R R
COPY jobs jobs

CMD rig run -r 4.2.0 -e "sessionInfo()"