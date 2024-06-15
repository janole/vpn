#!/bin/sh

if [ -z "${tls_serial_hex_0}" ]; then
    exit 0;
fi

SERIAL=`echo "${tls_serial_hex_0}" | sed "s/://g"`
SERIALDIR=$1

grep "^${X509_0_CN}$" "${SERIALDIR}/${SERIAL}" > /dev/null 2>&1

if [ $? -eq 0 ];
then
    echo "Serial ${SERIAL} for ${X509_0_CN} OK";
else
    echo "ERROR: Serial ${SERIAL} not found (${X509_0_CN})";
    exit 1
fi
