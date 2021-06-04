#!/bin/bash

var=`rpm -qa |grep jdk |grep fcs`

function set_jre() {

cd /usr/java
sudo unlink /usr/java/default &> /dev/null
sudo unlink /usr/java/latest  &> /dev/null
sudo ln -s /usr/java/latest default
sudo ln -s /etc/alternatives/jre latest

}


function set_jre180() {

cd /usr/java
sudo unlink /usr/java/default &> /dev/null
sudo unlink /usr/java/latest  &> /dev/null
sudo ln -s /usr/java/latest default
sudo ln -s /etc/alternatives/jre_1.8.0 latest

}


ls -l /etc/alternatives/jre &> /dev/null


if [ $? = 0 ]; then

  ls -l /usr/java &> /dev/null
  if [ $? = 0 ]; then

    set_jre

  else

    sudo mkdir /usr/java
    set_jre

  fi

else

  ls -l /etc/alternatives/jre_1.8.0 &> /dev/null
  if [ $? = 0 ]; then

    ls -l /usr/java &> /dev/null
    if [ $? = 0 ]; then

      set_jre180

    else

      sudo mkdir /usr/java
      set_jre180
    fi

  else         ###############

    if [ "$var" = "" ]; then
      echo
      echo 'No Java installed!'
      echo
      exit 0

    else
      sudo yum -y erase $var
      echo
      echo
      echo 'No OpenJDK installed. Oracle Java removed!'
      echo
      echo
      exit 0
    fi         ###############
  fi

fi


if [ "$var" = "" ]; then

  ls -l /etc/alternatives/jre &> /dev/null

  if [ $? = 0 ]; then

    set_jre
    echo
    echo 'The current OpenJDK installed is:'
    echo
    echo `/usr/java/latest/bin/java -version`

  else

    set_jre180
    echo
    echo 'The current OpenJDK installed is:'
    echo
    echo `/usr/java/latest/bin/java -version`


  fi


echo '--> No Oracle Java to remove!'
echo '--> OpenJDK symlinks modified'
echo
exit 0


fi


ls -l /etc/alternatives/jre &> /dev/null


if [ $? = 0 ]; then


  set_jre
  sudo yum -y erase $var


else

  set_jre180
  sudo yum -y erase $var


fi


if [ $? = 0 ]; then

  echo Success

else

  echo 'Yum was not able to remove Oracle Java. Please check the logs!'

fi

echo
echo
echo 'The current OpenJDK installed is:'
echo
echo `/usr/java/latest/bin/java -version`
