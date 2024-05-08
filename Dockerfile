FROM node:20-alpine
LABEL "repository"="https://github.com/EpiData-dk/modify-lazarus-versions"
LABEL "homepage"="https://github.com/EpiData-dk/modify-lazarus-versions"
LABEL "maintainer"="Torsten Bonde Christiansen"

RUN apk --no-cache add bash yq curl jq git && npm install -g semver

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
