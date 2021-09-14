FROM google/dart:2.13.4 as build

# Build Environment Vars
ARG BUILD_ID
ARG BUILD_NUMBER
ARG BUILD_URL
ARG GIT_COMMIT
ARG GIT_BRANCH
ARG GIT_TAG
ARG GIT_COMMIT_RANGE
ARG GIT_HEAD_URL
ARG GIT_MERGE_HEAD
ARG GIT_MERGE_BRANCH
WORKDIR /build/
ADD . /build/

RUN echo "Starting the script sections" && \
	dart --version && \
	pub get && \
	dartfmt --set-exit-if-changed --dry-run lib bin test tool && \ 
	pub run dependency_validator -x upgrade/ -i dart_dev && \
	pub run dart_dev analyze && \
	pub run abide || echo Abide would have failed CI. && \
	pub run test --concurrency=4 -p vm --reporter=expanded test/vm/ && \
	tar czvf abide.pub.tgz LICENSE README.md pubspec.yaml analysis_options.yaml lib/ bin/ && \
	echo "Script sections completed"
ARG BUILD_ARTIFACTS_DART-DEPENDENCIES=/build/pubspec.lock
ARG BUILD_ARTIFACTS_BUILD=/build/pubspec.lock
ARG BUILD_ARTIFACTS_PUB=/build/abide.pub.tgz
FROM scratch
