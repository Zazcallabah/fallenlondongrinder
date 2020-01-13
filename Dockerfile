FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
WORKDIR /app

COPY fl/*.csproj ./fl/
COPY localrunner/*.csproj ./localrunner/
WORKDIR /app/localrunner
RUN dotnet restore

WORKDIR /app/
COPY entrypoint.sh ./localrunner/
COPY fl/. ./fl/
COPY localrunner/. ./localrunner/
WORKDIR /app/localrunner
ENTRYPOINT ["/app/localrunner/entrypoint.sh"]
