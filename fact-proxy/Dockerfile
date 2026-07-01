# syntax=docker/dockerfile:1

FROM eclipse-temurin:25-jdk AS build
WORKDIR /app

COPY gradlew gradlew.bat settings.gradle build.gradle ./
COPY gradle ./gradle
COPY src ./src

RUN chmod +x gradlew && ./gradlew bootJar --no-daemon

FROM eclipse-temurin:25-jre
WORKDIR /app

COPY --from=build /app/build/libs/fact-proxy.jar app.jar

EXPOSE 3000
ENTRYPOINT ["java", "-jar", "app.jar"]
