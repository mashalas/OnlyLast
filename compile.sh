#!/usr/bin/sh

export program=OnlyLast

if [ -f  $program ]
then
  rm $program
fi

if [ -f ${program}.o ]
then
  rm ${program}.o
fi

fpc -Mobjfpc ${program}.pas
RetCode=$?

echo ----------------------------------------
if [ $RetCode -ne 0 ]
then
  echo Error! Cannot compile ${program}.pas
else
  ./$program files file*.txt -i 5 --verbose --sort-by=time
fi
echo ----------------------------------------
if [ -f ${program}.o ]
then
  rm ${program}.o
fi
