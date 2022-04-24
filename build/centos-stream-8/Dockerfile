ARG PKG_BUILDER
FROM ${PKG_BUILDER} as builder
ARG PACKAGE

WORKDIR /repo
COPY ${PACKAGE} .

RUN ./build.sh

FROM scratch

COPY --from=builder /repo/rpmbuild/RPMS/noarch/*.rpm .