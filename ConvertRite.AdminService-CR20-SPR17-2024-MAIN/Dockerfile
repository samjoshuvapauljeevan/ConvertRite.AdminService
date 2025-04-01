## Build stage
FROM maven:3.8.5-openjdk-17 AS maven_build
MAINTAINER RiteSoftware
COPY pom.xml /app/
COPY src /app/src
RUN mvn -f /app/pom.xml clean package  -e -DskipTests

## Run stage
FROM openjdk:17.0.1-jdk-slim
COPY --from=maven_build /app/target/admin-api-0.0.1-SNAPSHOT.jar /app/
COPY dbserver/sql /app/sql/
RUN apt-get update
RUN apt-get install net-tools
# this volume is mounted so that external configuration can be loaded
VOLUME /app/config

ARG SPRING_PROFILES_ACTIVE=dev
ENV SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE}
#adjusting the entrypoint accordingly to take in application props from external
ENTRYPOINT ["java", "-jar", "-Dspring.config.additional-location=/app/config/", "app/admin-api-0.0.1-SNAPSHOT.jar"]
EXPOSE 8080
