# fullpath-fake.sh: create a fake fullpath file with filehandle as path

cut -d',' -f1 - | sort -u | gawk '{ print $1 ",,/" $1 }'
