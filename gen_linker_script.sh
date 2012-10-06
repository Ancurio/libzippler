if [ $# -lt 3 ]
then
	echo "Too few arguments"
	exit
fi

echo $1 > $3
echo "{" >> $3
echo "global:" >> $3

semic=';'

cat $2 | while read line
do
	echo $line$semic >> $3
done

echo "local: *;" >> $3
echo "};" >> $3
