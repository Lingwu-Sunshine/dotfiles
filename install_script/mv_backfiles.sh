#!/bin/bash

####进行移动文件测试

currentlyPath=`pwd`
backupFilePath=${currentlyPath}"/../i3-wm-config/"
destinationPath="${HOME}/.config/"



files=(
    i3
    polybar
    rofi
    wallpaper
)

function cp_backup_file()
{
    CMD="cp -r"
    # CMD=""



    printf "\n copying backup files to ${HOME}/.config\n"
    for p in ${files[@]}; do

	${CMD} ${backupFilePath}${p} ${destinationPath}
    done
    printf "\ncopying successful"
}




function main()
{
    # echo ${currentlyPath}
    cp_backup_file
}

main
