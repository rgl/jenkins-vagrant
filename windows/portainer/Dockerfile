# escape=`
FROM mcr.microsoft.com/windows/nanoserver:1809 as builder
WORKDIR C:/Users/ContainerUser
ADD https://github.com/portainer/portainer/releases/download/1.22.0/portainer-1.22.0-windows-amd64.tar.gz portainer.tgz
RUN tar xf portainer.tgz

FROM mcr.microsoft.com/windows/nanoserver:1809
EXPOSE 9000
COPY --from=builder /Users/ContainerUser/portainer /app
# NB running as ContainerAdministrator is needed to access the docker named pipe.
USER ContainerAdministrator
RUN mkdir c:\data
VOLUME ["C:/data"]
WORKDIR /app
ENTRYPOINT ["/app/portainer.exe", "--no-auth", "--template-file", "templates.json"]
