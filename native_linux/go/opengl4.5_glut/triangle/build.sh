#!/bin/sh
GO111MODULE=off CGO_ENABLED=1 go build -o hello .
