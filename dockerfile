# build stage
FROM golang:1.24.5-alpine AS build
ENV GOTOOLCHAIN=auto
WORKDIR /src
RUN apk add --no-cache git build-base
RUN go install github.com/winebarrel/qube/cmd/qube@latest \
 && go install github.com/winebarrel/genlog/cmd/genlog@latest

# runtime stage
FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata zstd jq bash
COPY --from=build /go/bin/qube /usr/local/bin/qube
COPY --from=build /go/bin/genlog /usr/local/bin/genlog
WORKDIR /work
ENTRYPOINT ["/bin/bash"]
CMD ["-l"]