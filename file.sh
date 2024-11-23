#!/bin/bash
echo "Hello, welocome to the flipkart" > index.html
nohup busybox httpd -f -p 8080 &