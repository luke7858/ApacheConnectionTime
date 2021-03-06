#!/bin/bash

###################################
#####Colours######
ESC_SEQ="\x1b["
GREEN=$ESC_SEQ"32;01m"
RED=$ESC_SEQ"31;01m"
RESET=$ESC_SEQ"39;49;00m"
BLUE=$ESC_SEQ"34;01m"
INVERT="\e[7m"
#####################################

##################################

clear
neat="################################"

printf "$neat\n"
printf "\n"

####################################
check_distro() {
if [ `grep 'CentOS' /etc/*release | wc -l` -ge 1  ]; then
                Version=$(cat /etc/redhat-release | grep -Eo '[0-9]{1,4}' | head -1)
                Distro="CentOS"
elif [ `grep -i "hat" /etc/*release | wc -l` -ge 1 ]; then
                Version=$(cat /etc/redhat-release | grep -Eo '[0-9]{1,4}' | head -1)
                Distro="Red Hat"
else
                Distro=$(cat /etc/issue | head -1 | cut -d' ' -f1)
                case "$Distro" in
                "Ubuntu" )
                        Version=$(cat /etc/issue | head -1 | cut -d' ' -f2 | cut -d'.' -f1)
                ;;
                "Debian" )
                        Version=$( cat /etc/issue | head -1 | cut -d' ' -f3 )
                ;;
                esac
fi
}
apache_or_nginx() {
case $Distro in
'CentOS' | 'Red Hat' )
        nginxonff=$( rpm -qa nginx )
        httpdonoff=$( rpm -qa httpd )
                if [ "$nginxonoff" && "$httpdonoff"  ]; then
                        httpconfigport=$( grep ^Listen /etc/httpd/conf/httpd.conf | awk '{print $2}' )
                        nginxconfigport=$( grep 'listen' /etc/nginx/conf.d/default.conf | grep default | awk '{print $2}' )
                        #grep for port then compare with netstat
                elif [ "$nginxonoff" ]; then
                        nginxconfigport=$( grep 'listen' /etc/nginx/conf.d/default.conf | grep default | awk '{print $2}' )
                elif [ "$httponoff"  ]; then
                        httpconfigport=$( grep ^Listen /etc/httpd/conf/httpd.conf | awk '{print $2}' )
                fi
;;
'Ubuntu' | 'Debain' )

;;
esac
}
check_httpd() {
        case "$Distro" in
        "CentOS" )
                port=$( netstat -plnt | grep http | awk '{print $4}' | sed 's/://g' )
                httpdports=$( netstat -plnt | grep http | awk '{print $4}' | sed 's/://g' | wc -l )
        ;;
        "Ubuntu" )
        #if worker module then not going to work: apache2ctl -M 2>&1 | grep -c worker
                port=$( netstat -plnt | grep apache | awk '{print $4}' | sed 's/://g' )
                httpdports=$( netstat -plnt | grep apache | awk '{print $4}' | sed 's/://g' | wc -l )
        ;;
        "Debian" )
        #if worker module then not going to work: apache2ctl -M 2>&1 | grep -c worker
        	port=$( netstat -plnt | grep apache | awk '{print $4}' | sed 's/://g' )
                httpdports=$( netstat -plnt | grep apache | awk '{print $4}' | sed 's/://g' | wc -l )
        esac

                portcount=1
                arrayportcount=1
                portprintcounter=1

                while [ $portcount -le $httpdports ]; do
                        test=$( echo $port | awk '{ print $'$portcount' }'  )
                        portarray[$portcount]=$test
                        portcount=$[$portcount+1]
                done

                while [ $portprintcounter -lt $portcount ]; do #store in array
#                       printf "${portarray[$portprintcounter]}\n"
                        portprintcounter=$[$portprintcounter+1]
                done

                if [ $httpdports -ge 1 ]; then
                        for i in $(seq 1 $httpdports); do
                                printf "Apache Port:$GREEN ${portarray[$i]}$RESET \n"
                                i=$[$i+1]
                        done
                else
                        printf "Apache Port:$RED No port$RESET, Apache$RED NOT$RESET running\n"
                fi
}
check_nginx() {
#       nginxrunning=$( /etc/init.d/nginx status | grep -ic 'is running' )
#       nginxport=$( netstat -plnt | grep nginx | awk '{print $4}' | awk -F':' '{print $2}' )

        nginxport=$( netstat -tlpn | grep nginx | awk '{print $4}' | awk -F':' '{print $2}' )
        nginxports=$( netstat -plnt | grep nginx | awk '{print $4}' | sed 's/://g' | wc -l )
        portcount=1
        arrayportcount=1
        portprintcounter=1

        while [ $portcount -le $nginxports ]; do
                test=$( echo $nginxport | awk '{ print $'$portcount' }'  )
                nginxportarray[$portcount]=$test
                portcount=$[$portcount+1]
        done

        while [ $portprintcounter -lt $portcount ]; do #store in array
#               printf "${portarray[$portprintcounter]}\n"
                portprintcounter=$[$portprintcounter+1]
        done

        if [ $nginxports -ge 1 ]; then
                for i in $(seq 1 $nginxports); do
                        printf "Nginx Port:$GREEN ${nginxportarray[$i]}$RESET \n"
                        i=$[$i+1]
                done
        else
                printf "Nginx Port:$RED No port$RESET, Nginx$RED NOT$RESET running\n"
        fi


}
apache_buddy() {
        curl -s apache2buddy.pl | perl > /dev/null 2>&1; #run apache buddy and redirect output to /dev/null, we are only looking for the log files
        ab=$(grep -ohe 'Highest Pct .*' /var/log/apache2buddy.log | awk 'END{print $5}' | sed 's/"//g') #getting the ram % allocation for apache from logs produced above
        abram=$(grep -ohe 'Memory: .*' /var/log/apache2buddy.log | awk 'END{print $2}' | sed 's/"//g')
if [ "$Distro" == "CentOS" ] || [ "$Distro" == "Red Hat " ]; then
        currentconcentos=$(ps aux | grep -v grep | grep -ic /usr/sbin/httpd)
elif [ "$Distro" == "Ubuntu" ]; then
	currentconcentos=$(ps aux | grep -v grep | grep -ic /usr/sbin/apache)
fi
        MaxcRecommend=$(grep -ohe 'Reccommendedl .*' /var/log/apache2buddy.log | awk 'END{print $2}' | sed 's/"//g')
        MaxcConfigured=$(echo - | awk -v max=$MaxcRecommend -v current=$currentconcentos '{print max - current }')
}
ram_allocation() {
        case $ab in
        * )
                printf "Current RAM allocation to apache:$RED $ab%$RESET \n"
                printf "Apache Max RAM Usage: $abram MB\n"
                printf "Apache Configuration:$RED WARNING$RESET - Potentially Large Ram Allocation\n"
        ;;
        [0-85])
                printf "Current RAM allocation to apache:$RED $ab%$RESET \n"
                printf "Apache Max RAM Usage:$GREEN $abram$RESET MB\n"
                printf "Apache Configuration:$GREEN OK!$RESET\n"
        ;;
        esac
        printf "\n"
}
httpd_error_logs() {
        case $Distro in
        "CentOS" )
                errorlogformat=$(grep ^ErrorLog /etc/httpd/conf/httpd.conf | awk '{print $2}' | sed 's/.*[/]//' | sed 's/"//g')
                errorlogcentos=$( grep -i maxc /var/log/httpd/"$errorlogformat" | sort -k2M )
                zerrorlogcentos=$( zgrep -i maxc /var/log/httpd/"$errorlogformat"* )
        ;;
        "Ubuntu" )
                errorlogformat=$( grep ^ErrorLog /etc/apache2/apache2.conf | awk '{print $2}' | sed 's/.*[/]//' )

        ;;
        esac
}
error_logs_check() {
        if [ ! "$errorlogcentos" = "" ]; then
    # maxclients may have been hit a previous day, try to incoporate date in the search
                printf "$INVERT Error logs:$RESET \n"
                printf "$errorlogcentos\n"
        else #elif
                printf "\n"
                printf "$INVERT Error Logs:$RESET\n"
                printf "Nothing regarding MaxClients\n"
        fi
}
maxc_alert_warning() {
        printf "######$RED Configuration issue$RESET######\n"
        printf "###"$RED"MAX CLIENTS Currently Set too high!!$RESET###\n"
        printf "\n"
        printf "Max Clients in $BLUE/etc/httpd/conf/httpd.conf$RESET: $maxclientscentos\n"
        printf "Recommended connections: $BLUE$MaxcRecommend$RESET\n"
        printf "Difference = "$RED$difference$RESET
        printf "\n\n"
}
maxc_alert_ok() {
        printf "Configuration$GREEN OK!$RESET\n"
        printf "Max Clients in $BLUE/etc/httpd/conf/httpd.conf$RESET: $maxclientscentos\n"
        printf "\n"
        printf "Recommended connections: $BLUE$MaxcRecommend$RESET\n"
}
currentcon_alert_warning() {
        printf "$INVERT Current Status:$RESET Reached max connections!!: $MaxcConfigured\n"
        printf "$INVERT Status:$RESET$RED MAXIMUM!$RESET\n"
        printf "Current Conenctions: $currentconcentos \n"
        printf "Recommended connections: $BLUE$MaxcRecommend$RESET\n"
        printf "Remaining Available Connections = $RED$MaxcConfigured$RESET\n"
        printf "\n"
}
currentcon_alert_ok() {
        printf "$INVERT Current Status:$RESET$GREEN Not$RESET Reached Recommended Max Client\n"
        printf "$INVERT Status:$RESET$GREEN OK$RESET\n"
        printf "Current Conenctions: $currentconcentos \n"
        printf "Remaining Available Connections = $GREEN$MaxcConfigured$RESET\n"
        printf "\n"
}
currentcon_alert_close() {
        printf "$INVERT Current Status:$RESET$GREEN Not$RESET Reached Recommended Max Client\n"
        printf "$INVERT Status:$RESET$GREEN OK $RESET- However Max Connections$RED Nearly$RESET Reached!!\n"
        printf "Current Conenctions: $currentconcentos \n"
        printf "Remaining Available Connections = $RED$MaxcConfigured$RESET\n"
        printf "Recommended connections: $BLUE$MaxcRecommend$RESET\n"
    #look into configuration
        printf "\n"
}
alerts() {

#if [ $difference -lt 0 ]; then
        printf "Alerts Summary: Warning!\n"
        printf "Max Clients Status:\n"
        printf "Current Connections"
#elif [  ]; then
#fi
}
httpd_calculations() {
        apache_buddy
if [ "$Distro" == "CentOS" ] || [ "$Distro" == "Red Hat " ]; then
        maxclientscentos=$(grep MaxClients /etc/httpd/conf/httpd.conf | grep processes -A 1 | awk '{print $2}' | grep -v MaxClients) #current configured max connections
else
        maxclientscentos=$(grep MaxClients /etc/apache2/apache2.conf | grep processes -A 1 | awk '{print $2}' | grep -v MaxClients) #current configured max connections
fi
        httpd_error_logs
        difference=$(echo - | awk -v apachebuddy=$MaxcRecommend -v current=$maxclientscentos '{print apachebuddy - current}') #compare

                # alerts
printf "$neat\n"
printf "\n"

        if [ "$MaxcConfigured" -lt 1 ]; then #checking the current status of the configuration
            currentcon_alert_warning
        elif [ "$MaxcConfigured" -gt 10 ]; then
            currentcon_alert_ok
        elif [ "$MaxcConfigured" -ge 1 ] && [ "$MaxcConfigured" -le 10 ]; then
            currentcon_alert_close
        fi
printf "$neat\n"
printf "\n"

        if [ $difference -lt 0 ]; then #if apache maxclients configured badly then:
                maxc_alert_warning
        else
                maxc_alert_ok
        fi

        ram_allocation
        error_logs_check #checking error logs for possible max clients error

        printf "\n"
        printf "$neat\n"

        printf "$neat\n"
}
##################################
method1() {
case $httpdports in
 #-----------------------
        0 ) #if apache is not running:
                case $nginxports in
                0)
                        printf "Nginx not running\n"
                        printf "\n"
                        printf "$neat\n"
                ;;
                *)
                        printf "Server is running: Nginx\n"
                        printf "\n"
                ;;
                esac
#------------------------
        ;;
        * ) #if apache IS running:
                printf "Server is running: Apache\n"
                case $nginxports in
                        0)
                        ;;
                        *)
                                printf "Server is also running: Nginx\n"
                                printf "\n"
                        ;;
                        esac
                apache_buddy
                printf "\n"
                httpd_calculations
        ;;
        esac
}
show_connections() {
        Connections80443=$(netstat -ant | egrep ":80|:443" | egrep "ESTABLISHED|SYN_RECV" | awk '{ print $5 }' | sed -e 's/\:\:ffff\://g' | awk -F: '{print $1}' | sort | uniq -c | sort -nr |awk '{print $1 " "$2}')
        Connections80=$( netstat -plan|grep :80|awk {'print $5'}|cut -d: -f 1|sort|uniq -c|sort -nk 1  )
if [ "$Connections80443" = "" ]; then
        printf "$Connections80\n"
else
        printf "$Connections80443\n"
fi
}
established_connections() {
while [[ ! ( "$show_conn_yn" =~ "n" ) ]]; do
read -p "Would you like to show current connections? (y/n) " show_conn_yn
        case $show_conn_yn in
        y )
                show_connections
                exit
        ;;
        n )
                printf "Script Finished...\n"
        ;;
        *)
                printf "Please enter y or n: \n"
        ;;
        esac
done
}
##################################
########Start of code#############
##################################
        check_distro
if [ "$Distro" == "CentOS" ] && [ "$Version" -le 7 ] || [ "$Distro" == "Red Hat" ] && [ "$Version" -le 7 ]; then
        check_httpd
        check_nginx
        method1
elif [ "$Distro" == "Ubuntu" ] && [ "$Version" -gt 12 ] && [ $Version -le 14 ]; then
        printf "Ubuntu\n"
        check_httpd
        check_nginx
        method1
elif [ "$Distro" = "Debian" ] && [ "$Version" = 7 ]; then
        #printf "Debian Not Supported Yet\n"
	check_httpd
        check_nginx
        method1
else
        printf "Error! Server does not appear to be a supported version of Ubuntu or Centos\n"
fi
        established_connections
