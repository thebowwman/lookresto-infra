
FROM	golang:1.24	AS	builder
RUN	apt-get update && apt-get install -y \
	ca-certificates \
	&& update-ca-certificates
WORKDIR	/app
COPY	go.work	go.work.sum	./
COPY	cmd/api/go.mod	cmd/api/go.sum	./cmd/api/
COPY	kernel/go.mod	kernel/go.sum	./kernel/
COPY	restaurant/go.mod	restaurant/go.sum	./restaurant/
COPY	notification/go.mod	notification/go.sum	./notification/
COPY	shared/go.mod	shared/go.sum	./shared/
COPY	contracts/go.mod	contracts/go.sum	./contracts/
COPY	user/go.mod	user/go.sum	./user/
RUN	go work sync \
	&& (cd cmd/api \
	&& go mod download) \
	&& (cd kernel \
	&& go mod download) \
	&& (cd restaurant \
	&& go mod download) \
	&& (cd notification \
	&& go mod download) \
	&& (cd shared \
	&& go mod download) \
	&& (cd contracts \
	&& go mod download) \
	&& (cd user \
	&& go mod download)
COPY	.	.
RUN	CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -extldflags=-static" -o /bin/server ./cmd/api
FROM	debian:bookworm-slim
WORKDIR	/app
COPY	/bin/server	/app/app
COPY	/etc/ssl/certs/ca-certificates.crt	/etc/ssl/certs/
RUN	useradd -m appuser \
	&& mkdir -p /app/logs \
	&& chown -R appuser:appuser /app
USER	appuser
EXPOSE	8080
CMD	["/app/app"]
