echo "libzippler.so" > $1
echo "{" >> $1
echo "global:" >> $1

semic=';'

cat zippler.sym | while read line
do
	echo $line$semic >> $1
done

echo "local: *;" >> $1
echo "};" >> $1
