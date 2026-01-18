ARG JAVA_VERSION=21.0.4_7-jre-alpine

FROM eclipse-temurin:${JAVA_VERSION}
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY build/libs/*.jar /app/app.jar
USER app
EXPOSE 8088
ENTRYPOINT ["java","-jar","/app/app.jar"]
