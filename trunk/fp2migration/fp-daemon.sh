#!/bin/sh
MSGSDIR=${HOME}/msgs/FreeBSD/incoming
OUTPUTDIR=${HOME}/msgs/FreeBSD/xml-output
DESTDIR=${HOME}/msgs/FreeBSD/xml/

cd ${MSGSDIR}
while .
	do
	FILES=`echo *`

	if [ "$FILES" != "*" ]
	then
		for i in $FILES
			do
			echo $i
			${HOME}/scripts/load_xml_into_db.pl $i -R \
				> ${OUTPUTDIR}/$i \
				2>${OUTPUTDIR}/$i.errors

			# if errors file is zero size, rm it
			if [ -f ${OUTPUTDIR}/$i.errors ]
			then
				if [ ! -s ${OUTPUTDIR}/$i.errors ]
				then
					rm ${OUTPUTDIR}/$i.errors
				fi
			fi
			mv $i ${DESTDIR}
		done
	fi
	sleep 1
done
