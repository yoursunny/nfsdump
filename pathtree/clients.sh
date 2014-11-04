#!/bin/bash
# clients.sh: extract client IP addresses

gawk '$5 == "C3" { print substr($2, 0, 8) } ' - \
| sort -u \
| php -r '
while (FALSE !== ($l = fgets(STDIN))) {
  $l = trim($l);
  printf("%s,%s\n", $l, long2ip("0x".$l));
}
'
