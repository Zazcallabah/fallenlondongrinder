#!/bin/bash

TIME="$(date +%F_%H_%M_%S)"
dotnet test --filter RunAuto > "/var/testoutput/$TIME.txt"

find /var/testoutput -mtime +2 -type f -delete