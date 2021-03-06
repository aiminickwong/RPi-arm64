#!/bin/bash -e

DOCKER=$(which "docker")

if [ ! $DOCKER ]; then
	echo "error: no docker found!"
    echo "If you promise that you have installed docker correctly, please consider running as root."
    exit 1
fi

if ! $DOCKER ps >/dev/null; then
	echo "error connecting to docker:"
	$DOCKER ps
	exit 1
fi

CONTAINER_NAME=${CONTAINER_NAME-rpi_arm64_work}
CONTINUE=${CONTINUE-0}
VOLUME_ARGV="-v $(pwd)/build:/RPi-arm64/build -v $(pwd)/dist:/RPi-arm64/dist"

CONTAINER_EXISTS=$($DOCKER ps -a --filter name="$CONTAINER_NAME" -q)
CONTAINER_RUNNING=$($DOCKER ps --filter name="$CONTAINER_NAME" -q)

if [ "$CONTAINER_RUNNING" != "" ]; then
	echo "The build is already running in container $CONTAINER_NAME. Aborting."
	exit 1
fi
if [ "$CONTAINER_EXISTS" != "" ] && [ ! $CONTINUE -eq 1 ]; then
	echo "Container $CONTAINER_NAME already exists and you did not specify CONTINUE=1. Aborting."
	echo "You can delete the existing container like this:"
	echo "  $DOCKER rm -v $CONTAINER_NAME"
	exit 1
fi

$DOCKER build -t rpi_arm64_buildimg .

if [ "$CONTAINER_EXISTS" != "" ]; then
    trap "echo 'got Ctrl+C... please wait 5s'; $DOCKER stop -t 5 ${CONTAINER_NAME}_cont" SIGINT SIGTERM
    time $DOCKER run -it --rm --privileged $VOLUME_ARGV \
		--name "${CONTAINER_NAME}_cont" \
        rpi_arm64_buildimg \ 
        bash -o pipefail -c " \
            dpkg-reconfigure qemu-user-static && \
            busybox mdev -s; \
            cd /RPi-arm64; \
            ./build.sh "
else
    trap "echo 'got Ctrl+C... please wait 5s'; $DOCKER stop -t 5 ${CONTAINER_NAME}" SIGINT SIGTERM
    time $DOCKER run -it --privileged $VOLUME_ARGV \
        --name "${CONTAINER_NAME}" \
        rpi_arm64_buildimg \
        bash -o pipefail -c " \
            dpkg-reconfigure qemu-user-static && \
            busybox mdev -s; \
            cd /RPi-arm64; \
            ./build.sh "
fi

echo "Removing container $CONTAINER_NAME ..."
$DOCKER rm -v $CONTAINER_NAME
echo "Done! Your image should be in dist/"
