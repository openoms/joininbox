for value in $(cat candidates.txt | grep value | awk '{print $2}'|cut -d, -f1);do
  if [ ${#prev} -gt 0 ]&&[ $value -eq $prev ];then
    if [ $displayed -ne 1 ];then
      echo $value
      displayed=1
      prev=$value
    else
      echo displayed
    fi
  else
   prev=$value
   displayed=0
  fi
done

cat candidates.txt | grep value | awk '{print $2}'|cut -d, -f1 | tail -n 3| uniq -d



lastJMcjs=$(cat candidates.txt | grep "Joinmarket coinjoin" | tail -n 3 | awk '{print $5}')
for i in $lastJMcjs
do
  sudo -u bitcoin /home/joinmarket//bitcoin/scripts/checktransaction.sh $i
done