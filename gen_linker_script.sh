echo "libzippler.so" > $2
echo "{" >> $2
echo "global:" >> $2

semic=';'

cat $1 | while read line
do
	echo $line$semic >> $2
done

echo "local: *;" >> $2
echo "};" >> $2
