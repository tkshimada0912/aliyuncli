# aliyuncli

<div id="google_translate_element"></div><script type="text/javascript">
function googleTranslateElementInit() {
  new google.translate.TranslateElement({pageLanguage: 'ja', layout: google.translate.TranslateElement.InlineLayout.SIMPLE}, 'google_translate_element');
}
</script><script type="text/javascript" src="//translate.google.com/translate_a/element.js?cb=googleTranslateElementInit"></script>

これはAlibabaCloudのECS環境をコマンド一発で構築するための環境をDocker container内に作りあげるモノです。

- aliyuncliが導入されます。
- jqが導入されます。
- ansibleが導入されます。
- ECSインスタンスを起動し、ansibleユーザーを設定し、ansibleでの制御が可能な状態まで一発で設定するコマンドが使えます。
- Docker環境で構築されます。build/runして使ってください。

## Aliyun CLIでansibleな環境を作るためのDocker環境

### 背景

AlibabaCloudで複数のコンピューティングインスタンス（ECS）を作成するには、システムディスクイメージを作成して、クローニングするなどの方法がありますが、APIを使って作ってしまうほうが当然ながら簡単です。
しかしながら、AlibabaCloudのECSは、当然パラメータがいろいろあって、また、初期はpassword認証しか設定できなかったり、意外に”使える”状態に持っていくには手間がかかります。

そこで、aliyuncliコマンドをwrappingして、ansibleが使える環境を作るスクリプトと、オマケでRegion内の停止インスタンスを一発で消すスクリプト（俗には練習問題という）を作ってみました。

この環境を使うことで、以下が実現されます。

- aliyuncli、jq、ansibleが使えるDocker環境が構築されます。作業環境をimmutableにする試み。これによって、作業環境（端末とか、踏み台サーバーとか）も、環境依存から開放されます。
- createEcsコマンドは、aliyuncliにて、ECSを作成し、初期設定を行う一連の処理を行ってくれます。
- ECSを作成するときに必要となる「充分に複雑な」rootパスワードを自動設定してくれます（これだけで価値があると思っています）。
- ssh-keyを使って、ansibleユーザーでpublic keyでのログインを行い、sudoが使える初期環境をECS側に作ってくれます。ECSが完成したら、すぐにansibleでの操作が行えるようになります。
- ansible用のinventoryファイル（ファイル名＝hosts）も作成してくれます。

### getting started

まず、ssh-key/ssh-key.pubを作ります。これはECSにansibleでログインするために使う鍵です。
Dockerfileと同じフォルダに作っておきます。パスフレーズを空にすると、自動処理が可能になります。
パスフレーズを設定した場合、後述のssh-addの時にパスフレーズを一度入れれば、それ以降は聞かれません。

     ssh-keygen -t rsa -b 4096 -N '' -f ./ssh-key

Dockerfileを準備します。

    FROM centos
    RUN yum update -y && ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
    RUN yum install -y zsh wget epel-release
    RUN yum install -y ansible openssh-clients perl perl-Net-OpenSSH perl-IO-Pty-Easy
    RUN curl https://bootstrap.pypa.io/get-pip.py | python&& \
        pip install aliyuncli && pip install aliyun-python-sdk-ecs && pip install aliyun-python-sdk-rds && pip install aliyun-python-sdk-slb && pip install aliyun-python-sdk-oss
    RUN echo -e "source aliyun_zsh_complete.sh\ncomplete -C \`which aliyun_completer\` aliyuncli" > /root/.zshrc
    RUN wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -O /usr/local/bin/jq && chmod +x /usr/local/bin/jq
    RUN mkdir /root/.ssh && chmod 700 /root/.ssh && echo -e 'Host *\n\tUser ansible\n\tStrictHostKeyChecking no' > /root/.ssh/config
    COPY ssh-key* /root/
    ARG KEY_ID
    ARG KEY_SECRET
    ENV KEY_ID=$KEY_ID
    ENV KEY_SECRET=$KEY_SECRET
    RUN echo -e "$KEY_ID\n$KEY_SECRET\ncn-hongkong\njson\n" | aliyuncli configure > /dev/null

この環境は、aliyuncliとjqとansibleが動く環境です。上で作ったssh-keyペアを持ち込むのと、あとansibleで必要になるssh設定を行っています。ついでにzshの環境（auto complete）も整えます。AliyunのKEY_IDとKEY_SECRETはDockerfileに書きたくないので、「--build-arg」オプションでコマンドラインで渡します。

ビルドします。IDとSECRETはAlibabaCloud consoleから取得してください。

     docker build . -t aliyuncli_centos --build-arg KEY_ID=XXXX --build-arg KEY_SECRET=YYYY

スタートして、Docker環境で作業します。toolsをマウントするため、ディレクトリに注意してください。

     docker run -it --rm -v `pwd`/tools:/aliyuncli aliyuncli_centos env TERM=vt100 /bin/zsh

ちなみにdocker 1.10以降ではdetach-keyが設定可能になったため、Ctrl-Pでヒストリが辿れない（2回押さないといけない、しかも2回押すと2回分ヒストリが回る）事象が改善できます。下記は、「Ctrl-q q」でdetachする設定です。

     vi ~/.docker/config.json
     {
          "detachKeys": "ctrl-q,q"
     }
     
     ※ファイルが既にある場合、TOPのauthsセクションの並びに書く

toolsフォルダは/aliyuncliにマウントしていますが、ここに作業用ファイル（スクリプト）があります。

     createEcs
     deleteInstanceByRegion
     setup.sh

まず、deleteInstanceByRegionは、リージョンを指定すると停止しているインスタンスをすべて削除してくれるスクリプトです。

createEcsは、aliyuncli ecsコマンドのwrapperとして動作します。
setup.shは、インスタンス生成後、インスタンス内で初期設定を行うためのシェルのテンプレートです。

createEcsの起動方法について。オプションは「aliyuncli ecs CreateInstance」にそのまま渡されます。以下サンプルです。

     # cd /aliyuncli
     # ./createEcs --RegionId cn-beijing --ImageId centos7u0_64_40G_aliaegis_20160120.vhd --InstanceType ecs.s1.small --InternetChargeType PayByTraffic --InternetMaxBandwidthOut 20 --InternetMaxBandwidthIn 20

これで、約2分で、ECSが起動され、rootパスワードが「充分に複雑なもの」が設定され、ansibleユーザーがsudo可能な状態で作成され、ansibleユーザーでのssh-keyでのログインが有効化され、ansible用のinventoryファイル（./hosts）が生成されます。
コマンドラインの出力は以下のような感じです。下記では1分34秒で構築完了しています。

    [root@49e0ee1a7cca]/aliyuncli# ./createEcs --RegionId cn-beijing --ImageId centos7u0_64_40G_aliaegis_20160120.vhd --InstanceType ecs.s1.small --InternetChargeType PayByTraffic --InternetMaxBandwidthOut 20 --InternetMaxBandwidthIn 20
    Fri Jun 24 19:33:09 2016 [i-25xuxkwoo] Defined: i-25xuxkwoo
    Fri Jun 24 19:33:11 2016 [i-25xuxkwoo] public IP address: 123.57.47.212
    Fri Jun 24 19:33:11 2016 [i-25xuxkwoo] Root Password: jNCZMJ62cyh9CfTK
    Fri Jun 24 19:33:13 2016 [i-25xuxkwoo] Instance Started, waiting for SSH enabled.
    Fri Jun 24 19:33:26 2016 [i-25xuxkwoo] ssh Retry count:1
    Fri Jun 24 19:33:39 2016 [i-25xuxkwoo] ssh Retry count:2
    Fri Jun 24 19:33:52 2016 [i-25xuxkwoo] ssh Retry count:3
    Fri Jun 24 19:34:05 2016 [i-25xuxkwoo] ssh Retry count:4
    Fri Jun 24 19:34:18 2016 [i-25xuxkwoo] ssh Retry count:5
    Fri Jun 24 19:34:31 2016 [i-25xuxkwoo] ssh Retry count:6
    ssh: connect to host 123.57.47.212 port 22: Connection refused
    Fri Jun 24 19:34:37 2016 [i-25xuxkwoo] ssh Retry count:7
    Warning: Permanently added '123.57.47.212' (ECDSA) to the list of known hosts.
    Fri Jun 24 19:34:39 2016 [i-25xuxkwoo] setupcmd output:/etc/sudoers: parsed OK
    Fri Jun 24 19:34:39 2016 [i-25xuxkwoo] Server Startup finished. dur 1:34

これを複数回実行すると、指定したリージョンに複数ECSができます。

当然、Ansibleでの操作が可能です。

まずは、ansibleでsshするために、ssh-agentに鍵を読ませます。このとき、ssh-keyにパスフレーズが設定されているとパスフレーズを聞かれます（ssh-addする1回だけです）。

     # eval `ssh-agent` && ssh-add /root/ssh-key

以下、サンプルとして、4台サーバーを作った後のansible -m pingの動作例です。普通にansibleが使えます。

     /aliyuncli# ansible -i hosts -s -m ping all
     123.57.222.61 | SUCCESS => {
         "changed": false,
         "ping": "pong"
     }
     101.200.166.89 | SUCCESS => {
         "changed": false,
         "ping": "pong"
     }
     123.57.221.116 | SUCCESS => {
         "changed": false,
         "ping": "pong"
     }
     123.57.219.204 | SUCCESS => {
         "changed": false,
         "ping": "pong"
     }

操作例として、ansibleでhttpdを有効化してみます。

     # ansible -i hosts -s -m yum -a 'name=httpd state=present' all
     # ansible -i hosts -s -m service -a 'name=httpd state=started' all

これでhttpd✕4台起動完了です。あとはお好きに弄れます。

### 後片付け

作ったECS環境は、deleteInstanceByRegionというスクリプトで、簡単にリリースできます。
※インスタンスの停止には対応していませんので、consoleから停止してください。不慮の事故の抑止のためです。あまり意味は無いです。

     # ./deleteInstanceByRegion cn-beijing
     Get instance list
          1  i-253ao3pf7
          2  i-25g65o6qf
          3  i-25ynz2mxt
          4  i-25kvtj8l7
     Delete i-253ao3pf7
     Delete i-25g65o6qf
     Delete i-25ynz2mxt
     Delete i-25kvtj8l7

これでECSインスタンスは綺麗になくなります。AlibabaCloudのECSは停止していても課金の対象となりますので、サンプルインスタンスは速やかに片付けることをお勧めします（私はこれを知らず痛い目を見ましたので、インスタンスの残置状態は常に気にしています）。

最後に、作業用に作ったDocker環境も消してしまって問題ありません。「--rm」オプションを付けてrunしていれば、ログアウトした段階で消えています。

     docker rm b26

また明日作業するときは、docker runから始めることができます。
ヒストリ等は消えてしまいますが、毎日クリーンな環境から作業を行うことができます。

以上
