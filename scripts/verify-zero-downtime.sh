#!/usr/bin/env bash

set -u

URL="http://127.0.0.1/healthz"
DURATION="${1:-120}"

TOTAL=0
SUCCESS=0
FAILED=0
HTTP_5XX=0

START=$(date +%s)
END=$((START + DURATION))

echo "Starting zero-downtime test"
echo "URL: $URL"
echo "Duration: ${DURATION}s"
echo "Press Ctrl+C to stop early."

while [ "$(date +%s)" -lt "$END" ]; do
    TOTAL=$((TOTAL + 1))

    CODE=$(curl -sS -o /dev/null \
        -w "%{http_code}" \
        --connect-timeout 2 \
        --max-time 5 \
        "$URL" 2>/dev/null) || CODE="000"

    if [[ "$CODE" =~ ^2[0-9][0-9]$ ]]; then
        SUCCESS=$((SUCCESS + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    if [[ "$CODE" =~ ^5[0-9][0-9]$ ]]; then
        HTTP_5XX=$((HTTP_5XX + 1))
    fi

    printf 'Requests: %d | Success: %d | Failed: %d | 5xx: %d | Last HTTP: %s\n' \
        "$TOTAL" "$SUCCESS" "$FAILED" "$HTTP_5XX" "$CODE"

    sleep 0.2
done

echo
echo "========== TEST SUMMARY =========="
echo "Total requests: $TOTAL"
echo "Successful 2xx responses: $SUCCESS"
echo "Failed/non-2xx requests: $FAILED"
echo "HTTP 5xx responses: $HTTP_5XX"

if [ "$TOTAL" -gt 0 ]; then
    awk -v s="$SUCCESS" -v t="$TOTAL" \
        'BEGIN { printf "Success rate: %.2f%%\n", (s/t)*100 }'
fi