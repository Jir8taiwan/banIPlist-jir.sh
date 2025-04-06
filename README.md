# banIPlist-jir.sh
Using IPSET and IPTABLES to preload understood bad IPs to drop connections

目前透過的免費方案有這五個：
1. https://www.abuseipdb.com/ 這個AbuseIPDB可以免費註冊拿到API，但是每天有更新限制次數。
2. Emerging Threats的清單https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt
3. FireHOL的清單https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset
4. Blocklist.de的清單https://lists.blocklist.de/lists/all.txt
5. Spamhaus的清單https://www.spamhaus.org/drop/drop.txt

透過一個簡單的script指令和設定來定時下載更新檔案，然後合併處理移除彼此重複的IP值。
最後就會產出一個ip.blacklist檔案，隨時可以拿來利用。
PS. 截至目前為止，已知的IPV4惡意IP約快9萬個、IPV6約快3千個。

也許有人是純用iptables，或者firewalld延伸應用。
接下來script的範例檔案，是目前測試出來的可以用的做法。
首先，要先確認是不是都有安裝到這些套件：

sudo apt install ipset iptables netfilter-persistent ipset-persistent iptables-persistent

修改可執行

sudo chmod +x ./banIPlist-jir.sh

執行，這個筆數越大，整體執行時間會越久。

sudo ./banIPlist-jir.sh

最後，上面的檔案如果執行完成、也正常運作。
我們讓它遇到重開機時，先預先載入復原這個防護狀態。要執行備份和功能啟用。
設定存檔

sudo netfilter-persistent save
sudo ipset-persistent save

或者這樣存檔

sudo dpkg-reconfigure ipset-persistent
sudo dpkg-reconfigure iptables-persistent

啟用和檢查

sudo systemctl enable netfilter-persistent
sudo systemctl start netfilter-persistent
sudo systemctl status netfilter-persistent

然後，有必要好用的話，可以寫到crontab，固定間隔就更新新的黑名單IP。
另外，我有寫特別的參數值，--apply-ipset是讓iptables設定值意外清空的時候，可以預載回來。
可以用這兩個指令來查看：

sudo iptables -L INPUT -v -n
sudo ip6tables -L INPUT -v -n



文章放在：
https://jir.idv.tw/wordpress/?p=3176

****
If this small code is helping through Arduino kits, it can donate BCH coin to me for encourage as following address:

    BTC - 3M4wWghm4MxmrSfXmHMEeCFNwP8Lxxqjzk
    BCH - bitcoincash:qq6ghvdmyusnse9735rd5q09ensacl8z8qzrlwf49q
    LTC - MR6HaFkfkmsfifX3jWu7xz33dULGotVUWB
    DOGE- DGEFd3AAfJrBuaUwc4P6R2ZT754Jon9fQ7

Thank you very much.
