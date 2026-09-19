FROM docker.io/library/golang:1.23-alpine AS build
WORKDIR /app
COPY go.mod ./
RUN go mod download 2>/dev/null || true
COPY . .
RUN go mod tidy && CGO_ENABLED=0 go build -o server .

FROM docker.io/library/alpine:3.20
RUN apk add --no-cache ca-certificates
COPY --from=build /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
