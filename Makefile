SHELL := /bin/bash
.DEFAULT_GOAL := build
.PHONY: build publish test

MAKEFILE_PATH := $(abspath $(lastword ${MAKEFILE_LIST}))
PROJECT_PATH := $(dir ${MAKEFILE_PATH})
PROJECT_NAME := $(notdir $(patsubst %/,%,$(dir ${PROJECT_PATH})))

export DOCKER_BUILDKIT ?= 1
export IMAGE_REGISTRY := docker.io
export IMAGE_USER := gbmcarlos
export IMAGE_REPO := php-runtime
export IMAGE_TAG := latest
export ARCHES := arm64 amd64
export IMAGE_NAME := ${IMAGE_REGISTRY}/${IMAGE_USER}/${IMAGE_REPO}:${IMAGE_TAG}

export XDEBUG_ENABLED ?= true
export XDEBUG_REMOTE_HOST ?= host.docker.internal
export XDEBUG_REMOTE_PORT ?= 10000
export XDEBUG_IDE_KEY ?= ${APP_NAME}_PHPSTORM
export MEMORY_LIMIT ?= 3M

export _HANDLER ?= index

build:
	for arch in ${ARCHES}; do \
		docker build \
		--platform linux/$$arch \
		-t ${IMAGE_NAME}-$$arch \
		--target base \
		--build-arg BASE_IMAGE_USER=${IMAGE_USER} \
		--build-arg BASE_IMAGE_TAG=${IMAGE_TAG} \
		--build-arg BASE_IMAGE_ARCH=$$arch \
		${CURDIR} ; \
	done

publish: build
	docker manifest rm ${IMAGE_NAME} | true
	for arch in ${ARCHES}; do \
  		docker push ${IMAGE_NAME}-$$arch ; \
  		docker manifest create ${IMAGE_NAME} --amend ${IMAGE_NAME}-$$arch ; \
	done
	docker manifest push ${IMAGE_NAME}

test: build
	docker build \
 	-t ${IMAGE_USER}/${IMAGE_REPO}-test \
 	 --target test \
 	 ${CURDIR}/tests

	docker run \
	--name ${IMAGE_REPO}-test \
	--rm \
	-i \
	-e APP_DEBUG \
	-e XDEBUG_ENABLED \
	-e XDEBUG_REMOTE_HOST \
	-e XDEBUG_REMOTE_PORT \
	-e XDEBUG_IDE_KEY \
	-e _HANDLER \
	-p 8080:8080 \
	--entrypoint /opt/lambda-entrypoint.sh \
	${IMAGE_USER}/${IMAGE_REPO}-test