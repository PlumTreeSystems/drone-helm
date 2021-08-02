FROM golang:1.14 as builder

WORKDIR /tmp/build
COPY . .
RUN GOOS=linux go build -mod=vendor -ldflags="-s -w"

# ---

FROM alpine as downloader

ARG HELM_VERSION=3.5.0
ENV HELM_URL=https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz

ARG KUBECTL_VERSION=1.19.7
ENV KUBECTL_URL=https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl

WORKDIR /tmp
RUN true \
  && wget -O helm.tgz "$HELM_URL" \
  && tar xvpf helm.tgz linux-amd64/helm \
  && mv linux-amd64/helm /usr/local/bin/helm \
  && wget -O /usr/local/bin/kubectl "$KUBECTL_URL" \
  && chmod +x /usr/local/bin/kubectl

# ---
FROM golang:1.13-alpine3.10 AS sops

RUN apk --no-cache add make git
RUN git clone https://github.com/mozilla/sops.git /go/src/go.mozilla.org/sops
WORKDIR /go/src/go.mozilla.org/sops
RUN pwd
RUN ls -la
RUN ls -la /go/src/go.mozilla.org/sops
RUN CGO_ENABLED=1 make install


FROM alpine
RUN apk --no-cache add \
  vim ca-certificates git wget gnupg
ENV EDITOR vim
COPY --from=sops /go/bin/sops /usr/local/bin/sops
COPY --from=downloader /usr/local/bin/helm /usr/local/bin/helm
COPY --from=downloader /usr/local/bin/kubectl /usr/local/bin/kubectl

COPY --from=builder /etc/ssl/certs /etc/ssl/certs
COPY --from=builder /tmp/build/drone-helm3 /usr/local/bin/drone-helm3
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version v3.8.2
RUN mkdir /root/.kube

CMD /usr/local/bin/drone-helm3
