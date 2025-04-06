#!/bin/bash
### 250406 with IPset mode to block mass IPs.
# 設定黑名單檔案儲放路徑和處理的暫存位置
BLACKLIST_FILE="/etc/fail2ban/ip.blacklist"
TEMP_FILE="/var/tmp/ip.blacklist.tmp"
# 日誌檔案的路徑和異常通知信的收件人
LOG_FILE="/var/log/iptables_blacklist_jir.log"
NOTIFY_EMAIL="FaultReceiveUser@on.the.net"
# ipset 名稱
SET_NAME="blacklist_jir"
SET_NAME_IPV6="blacklist_jir_ipv6"

echo "$(date '+%Y-%m-%d %H:%M:%S') starting... banIPlist-jir.sh ..." | tee -a $LOG_FILE

# 檢查是否帶入 --apply-ipset 參數
if [[ "$1" == "--apply-ipset" ]]; then
    echo "只執行 ipset 規則應用到 iptables..." | tee -a $LOG_FILE
    # 刪除舊的 IPSET 規則（如果存在）
    for i in $(sudo iptables -L INPUT -n --line-numbers | grep $SET_NAME | awk '{print $1}' | sort -nr); do
        sudo iptables -w -D INPUT $i | tee -a $LOG_FILE
    done
    for i in $(sudo ip6tables -L INPUT -n --line-numbers | grep $SET_NAME_IPV6 | awk '{print $1}' | sort -nr); do
        sudo ip6tables -w -D INPUT $i | tee -a $LOG_FILE
    done

    # 套用 ipset 到 iptables 和 ip6tables
    sudo iptables -w -I INPUT -m set --match-set $SET_NAME src -j DROP | tee -a $LOG_FILE
    sudo ip6tables -w -I INPUT -m set --match-set $SET_NAME_IPV6 src -j DROP | tee -a $LOG_FILE
    echo "完成 ipset 規則應用。" | tee -a $LOG_FILE
    
	#### 選用的功能OPTIONAL: 
    echo "只執行 封鎖webmin port: 10000 規則應用到 iptables..." | tee -a $LOG_FILE
    # 刪除舊的 封鎖webmin 規則（如果存在）到 iptables 和 ip6tables
    for i in $(sudo iptables -L INPUT -n --line-numbers | grep 'tcp dpt:10000' | awk '{print $1}' | sort -nr); do
        sudo iptables -w -D INPUT $i | tee -a $LOG_FILE | tee -a $LOG_FILE
    done
    # 
    for i in $(sudo ip6tables -L INPUT -n --line-numbers | grep 'tcp dpt:10000' | awk '{print $1}' | sort -nr); do
        sudo ip6tables -w -D INPUT $i | tee -a $LOG_FILE | tee -a $LOG_FILE
    done
    # 套用 封鎖webmin 本機以外的連線 到 iptables 和 ip6tables
    sudo iptables -w -A INPUT -p tcp -s 127.0.0.1 --dport 10000 -j ACCEPT | tee -a $LOG_FILE
    sudo iptables -w -A INPUT -p tcp --dport 10000 -j REJECT | tee -a $LOG_FILE
    # 
	sudo ip6tables -A INPUT -p tcp -s ::1 --dport 10000 -j ACCEPT | tee -a $LOG_FILE
    sudo ip6tables -w -A INPUT -p tcp --dport 10000 -j REJECT | tee -a $LOG_FILE
    echo "完成 封鎖webmin port: 10000 規則應用。" | tee -a $LOG_FILE
	####

    exit 0
fi

# 獲取當前外部浮動IP (IPv4 and IPv6)
CURRENT_IP=$(curl -s4 ifconfig.me)
CURRENT_IPv6=$(curl -s6 ifconfig.me)
# 驗證IP地址獲取是否成功
if [ -z "$CURRENT_IP" ] && [ -z "$CURRENT_IPv6" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') 錯誤：無法獲取當前IP地址" | tee -a $LOG_FILE
    exit 1
fi
# 檢查當前自己的IP是否在黑名單中
if grep -q "^$CURRENT_IP$" $BLACKLIST_FILE; then
  SUBJECT="警告: 外部IP $CURRENT_IP 在黑名單中 detected"
  BODY="您的外部IP地址 $CURRENT_IP 被列入黑名單。請檢查並處理。\n\n狀態: 列入黑名單"
  echo -e "$BODY" | mail -s "$SUBJECT" "$NOTIFY_EMAIL"
  
  # 移除當前IP地址
  echo "$(date '+%Y-%m-%d %H:%M:%S') handle...外部IP $CURRENT_IP 在黑名單中 detected" | tee -a $LOG_FILE
  grep -v "^$CURRENT_IP$" $BLACKLIST_FILE > $TEMP_FILE && mv $TEMP_FILE $BLACKLIST_FILE
fi

# 檢查當前自己的IPv6是否在黑名單中
if grep -q "^$CURRENT_IPv6$" $BLACKLIST_FILE; then
  SUBJECT="警告: 外部IPv6 $CURRENT_IPv6 在黑名單中 detected"
  BODY="您的外部IPv6地址 $CURRENT_IPv6 被列入黑名單。請檢查並處理。\n\n狀態: 列入黑名單"
  echo -e "$BODY" | mail -s "$SUBJECT" "$NOTIFY_EMAIL"
  
  # 移除當前IPv6地址
  echo "$(date '+%Y-%m-%d %H:%M:%S') handle...外部IPv6 $CURRENT_IPv6 在黑名單中 detected" | tee -a $LOG_FILE
  grep -v "^$CURRENT_IPv6$" $BLACKLIST_FILE > $TEMP_FILE && mv $TEMP_FILE $BLACKLIST_FILE
fi

# 清除舊規則和ipset集合（如果存在）
echo "$(date '+%Y-%m-%d %H:%M:%S') 清除舊的 IPv4 和 IPv6 規則和 ipset 集合..." | tee -a $LOG_FILE
# 刪除舊的 IPSET 規則（如果存在）
for i in $(sudo iptables -L INPUT -n --line-numbers | grep $SET_NAME | awk '{print $1}' | sort -nr); do
    sudo iptables -w -D INPUT $i | tee -a $LOG_FILE
done
for i in $(sudo ip6tables -L INPUT -n --line-numbers | grep $SET_NAME_IPV6 | awk '{print $1}' | sort -nr); do
    sudo ip6tables -w -D INPUT $i | tee -a $LOG_FILE
done

# 刪除firewall-cmd: IPv4 and IPv6 規則
echo "將 ipset 集合 刪除 firewalld ..." | tee -a $LOG_FILE
sudo firewall-cmd --direct --remove-rule ipv4 filter INPUT 0 -m set --match-set $SET_NAME src -j DROP | tee -a $LOG_FILE
sudo firewall-cmd --direct --remove-rule ipv6 filter INPUT 0 -m set --match-set $SET_NAME_IPV6 src -j DROP | tee -a $LOG_FILE

# 檢查並刪除已存在的 ipset 集合
echo "$(date '+%Y-%m-%d %H:%M:%S') 檢查並刪除已存在的 ipset 集合..." | tee -a $LOG_FILE
if sudo ipset list $SET_NAME > /dev/null 2>&1; then
    sudo ipset destroy $SET_NAME | tee -a $LOG_FILE
    echo "$(date '+%Y-%m-%d %H:%M:%S') 刪除ipset集合 $SET_NAME" | tee -a $LOG_FILE
fi
if sudo ipset list $SET_NAME_IPV6 > /dev/null 2>&1; then
    sudo ipset destroy $SET_NAME_IPV6 | tee -a $LOG_FILE
    echo "$(date '+%Y-%m-%d %H:%M:%S') 刪除ipset集合 $SET_NAME_IPV6" | tee -a $LOG_FILE
fi

# 創建新的 ipset 集合來處理已知近10萬筆封鎖IP
echo "$(date '+%Y-%m-%d %H:%M:%S') 創建新的 IPv4 和 IPv6 ipset 集合..." | tee -a $LOG_FILE
sudo ipset create $SET_NAME hash:ip hashsize 262144 maxelem 100000 | tee -a $LOG_FILE
sudo ipset create $SET_NAME_IPV6 hash:ip family inet6 hashsize 32768 maxelem 100000 | tee -a $LOG_FILE

# 讀取黑名單中的每個 IP 並根據其類型添加到 ipset 集合中
echo "$(date '+%Y-%m-%d %H:%M:%S') 開始添加 IP 地址到 ipset 集合..." | tee -a $LOG_FILE
IPV4_ADDRESSES=()
IPV6_ADDRESSES=()

while read -r ip; do
    # 跳過空行
    if [[ -z "$ip" ]]; then
        continue
    fi
    # 檢查是否為 IPv6 地址
    if [[ "$ip" =~ : ]]; then
        # 添加 IPv6 地址到列表
        IPV6_ADDRESSES+=($ip)
    else
        # 添加 IPv4 地址到列表
        IPV4_ADDRESSES+=($ip)
    fi
done < "$BLACKLIST_FILE"

# 批量添加 IPv4 地址到 ipset 集合
for ip in "${IPV4_ADDRESSES[@]}"; do
    sudo ipset add $SET_NAME $ip
    echo "$(date '+%Y-%m-%d %H:%M:%S') 添加 IPv4 地址到 ipset: $ip" | tee -a $LOG_FILE
done

# 批量添加 IPv6 地址到 ipset 集合
for ip in "${IPV6_ADDRESSES[@]}"; do
    sudo ipset add $SET_NAME_IPV6 $ip
    echo "$(date '+%Y-%m-%d %H:%M:%S') 添加 IPv6 地址到 ipset: $ip" | tee -a $LOG_FILE
done

# 刪除舊的 IPSET 規則（如果存在）
for i in $(sudo iptables -L INPUT -n --line-numbers | grep $SET_NAME | awk '{print $1}' | sort -nr); do
    sudo iptables -w -D INPUT $i | tee -a $LOG_FILE
done
for i in $(sudo ip6tables -L INPUT -n --line-numbers | grep $SET_NAME_IPV6 | awk '{print $1}' | sort -nr); do
    sudo ip6tables -w -D INPUT $i | tee -a $LOG_FILE
done
# 將 ipset 集合應用到 iptables 和 ip6tables
echo "將 ipset 集合應用到 iptables 和 ip6tables..." | tee -a $LOG_FILE
sudo iptables -w -I INPUT -m set --match-set $SET_NAME src -j DROP | tee -a $LOG_FILE
sudo ip6tables -w -I INPUT -m set --match-set $SET_NAME_IPV6 src -j DROP | tee -a $LOG_FILE

###
echo "將 ipset 集合應用到 firewalld ..." | tee -a $LOG_FILE
sudo firewall-cmd --direct --add-rule ipv4 filter INPUT 0 -m set --match-set $SET_NAME src -j DROP | tee -a $LOG_FILE
sudo firewall-cmd --direct --add-rule ipv6 filter INPUT 0 -m set --match-set $SET_NAME_IPV6 src -j DROP | tee -a $LOG_FILE
###

# show status in the end
echo "$(date '+%Y-%m-%d %H:%M:%S') iptables -L INPUT -v -n | grep $SET_NAME" | tee -a $LOG_FILE
sudo ipset list $SET_NAME | grep "Header: family inet hashsize" | tee -a $LOG_FILE
sudo ipset list $SET_NAME | grep "Number of entries" | tee -a $LOG_FILE
echo "$(date '+%Y-%m-%d %H:%M:%S') iptables -L INPUT -v -n | grep $SET_NAME_IPV6" | tee -a $LOG_FILE
sudo ipset list $SET_NAME_IPV6 | grep "Header: family inet hashsize" | tee -a $LOG_FILE
sudo ipset list $SET_NAME_IPV6 | grep "Number of entries" | tee -a $LOG_FILE
#
echo "$(date '+%Y-%m-%d %H:%M:%S') ip6tables -L INPUT -v -n | grep $SET_NAME_IPV6" | tee -a $LOG_FILE
sudo iptables -L INPUT -v -n | grep $SET_NAME | tee -a $LOG_FILE
sudo ip6tables -L INPUT -v -n | grep $SET_NAME_IPV6 | tee -a $LOG_FILE

#
sudo netfilter-persistent save
sudo ipset-persistent save


echo "$(date '+%Y-%m-%d %H:%M:%S') Finished ... banIPlist-jir.sh ..." | tee -a $LOG_FILE
exit 0
