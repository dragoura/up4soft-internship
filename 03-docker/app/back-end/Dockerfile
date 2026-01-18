ARG GRADLE_VERSION=8.5.0-jdk21 
ARG JAVA_VERSION=21.0.4_7-jre-alpine

FROM gradle:${GRADLE_VERSION} AS builder
WORKDIR /project
COPY build.gradle settings.gradle gradle/ ./
RUN --mount=type=cache,target=/home/gradle/.gradle/caches,sharing=locked \
    --mount=type=cache,target=/home/gradle/.gradle/wrapper,sharing=locked \
    gradle --no-daemon dependencies
COPY src ./src
RUN --mount=type=cache,target=/home/gradle/.gradle/caches,sharing=locked \
    --mount=type=cache,target=/home/gradle/.gradle/wrapper,sharing=locked \
    gradle --no-daemon bootJar -x test


FROM eclipse-temurin:${JAVA_VERSION}
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder /project/build/libs/*.jar /app/app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
