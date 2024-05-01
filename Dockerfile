FROM alpine:3.19
LABEL "repository"="https://github.com/EpiData-dk/modify-lazarus-versions"
LABEL "homepage"="https://github.com/EpiData-dk/modify-lazarus-versions"
LABEL "maintainer"="Torsten Bonde Christiansen"

RUN apk --no-cache add bash yq

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
