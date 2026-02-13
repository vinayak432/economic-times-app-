FROM maven:3.9.12-eclipse-temurin-21-alpine as mavenbuilder
#ARG TEST=/var/lib/
WORKDIR /app
COPY . .
RUN mvn clean package

FROM tomcat:10.1-jdk21
#ARG TEST=/var/lib
COPY --from=mavenbuilder /app/target/economic-times-app.war /usr/local/tomcat/webapps

~                             
