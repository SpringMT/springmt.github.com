!slide
#  「apache,nginx × passenger,unicornのベンチをとってみた」+ デザート
* 2012/03/21
* @Spring_MT

* **ツッコミは随時入れてください！！！**

!slide
### 自己紹介
* **名前**
    * 春山 誠
    * twitter id : @Spring_MT <image style="height: 50px" src="images/tiwtter_logo.jpg"/>

* **経歴**
    * 2008/4 〜 2012/1 **DeNA**
        * 2008〜2010までは「みんなのウェディング」で企画
        * 2010〜はyahoo-mobage でエンジニア
    * 2012/3 〜        **10xlab**

* 最近markdown厨です
    * Mouいいですよ
    * 今回のプレゼンもmarkdownで書いてます

!slide
### 最近「apache,nginx × passenger,unicornのベンチをとってみた」というエントリを書きました。
* その理由は・・・
    1. 10xlabのプロジェクトでruby(rails)を使う
    1. **railsでwebサーバーのベストな構成がわからない**
        * apacheやnginx単体のbenchはあるけど、appサーバーも含めてとったベンチって意外とない
        * nginx + unicornを使ったら早くなったってエントリが結構あるけど、ほぼベンチ取ってない
    1. 今ならまだ余裕があるからベンチとれる！
    {: class="build" }

!slide
# ってことでベンチ取って比較してみました。
* ただ、ベンチ取る前から、unicornを採用することはほぼ自分の中では決まっていました・・・

!slide
### unicornを採用することが決まっていた理由
* 主に運用する際のメリットが大きいからです。

#### メリット
{: class="green" }

* forkを使ったmaster⇔worker構造を取る
    * copy on wirteによるメモリの効率化
    * masterがうまくworkerを管理しているので詰まることが少ない
* deploy時のダウンタイムが(ほぼ)ない
    * masterにHUPを送ると、新しいworkerをforkした後に、古いworkerと入れ替える

!slide
### 構成
<image class="lefted" style="height: 600px" src="images/app_server_map.jpg"/>

!slide
### 構成
<image class="lefted" style="height: 600px" src="images/app_server_mod_hoge.jpg"/>

!slide
### テストの環境
* webアプリを動かしてるマシン  
    * **KVM上の仮想マシンです**
    {: class="red" }

|項目 | 詳細 |
|:---:|:---:|
| os | fedora16 |
| CPU | QEMU Virtual CPU version 0.15.1 |
| CPU数 | 4 |
| memory | 2GB |
  
!slide
### テストの環境
* ベンチとったマシン

| 項目 | 詳細 |
|:---:|:---:|
| os | Ubuntu |
| CPU | Quad Core Xeon E3-1225 |
| CPU数 | 4 |
| memory | 16GB |

!slide
### テストの環境
* ライブラリのバージョン

| version | 設定 |
|:---:|:---:|
| apache | 2.2.21 | 
| nginx | 1.0.12  |
| passenger | 3.0.11 |
| unicorn | 4.2.0 |

!slide
### apacheの設定

~~~~~
KeepAlive Off

StartServers       8
MinSpareServers    5
MaxSpareServers   20
ServerLimit      256
MaxClients       256
MaxRequestsPerChild  4000
~~~~~

!slide
### nginxの設定

~~~~~
worker_processes  5;
events {
    worker_connections  1024;
}
http {
    keepalive_timeout  0;
}
~~~~~

!slide
### アプリ
* 今回のテストでは、Hello World!を表示させるだけのアプリを作りました

* <script src="https://gist.github.com/2137511.js?file=gistfile1.txt"></script>


!slide
# 結果発表
* パフォーマンスは 秒間あたりに捌けるリクエスト数で比較しています

!slide
### リクエスト数を1000で固定し、同時接続数を増やす

#### **nginx + unicornは動的ベージの表示では決して早くない**
{: class="red" }

* <image style="width: 700px" src="images/req_1000_4.jpg"/>


!slide
### CPUの2個、4個で比較

#### CPUが少ないと、違った傾向になるのでベンチとるときは注意

* <image style="width: 350px" src="images/req_1000_4.jpg"/> <image style="width: 350px" src="images/req_1000_2.png"/>

* 左がCPU4個、右がCPU2個の結果

!slide
### 同時接続数を固定して、リクエスト数を増やす

#### nginxは同時接続数が増えると性能が大きく上がる

* <image style="width: 360px" src="images/conc_10_4.jpg"/> <image style="width: 360px" src="images/conc_50_4.png"/>
* 左が同時接続数10、右が同時接続数50で固定した結果

!slide
### starmanと比べてみた

#### **starman爆速！！！**
{: class="red" }

* @miyagawaと@kazuhoの作品だけあってパフォーマンスはハンパねぇ
* <image style="width: 600px" src="images/req_1000_perl_4.jpg"/>

!slide
### 静的ファイルの配信 リクエスト1000で固定

#### 静的ファイルだと、圧倒的にnginxのほうがパフォーマンスが圧倒的
* <image style="width: 600px" src="images/apche_nginx_static.jpg"/>


!slide
### その他補足
* unicornのプロセス数が多すぎとtwitterで突っ込まれたのですが、減らしても特にパフォーマンスは変わりませんでした。
* nginxでunix socketを使った場合、一割位性能があがります。
* thinを使った場合、6000 req / secくらいのパフォーマンスがでました！

!slide
# 結論
  
### nginx + unicornは動的ページのパフォーマンスに関しては、ベストではない

* 軽量フレームワークかつ静的ページの配信が少ないのであれば、apache + passengerでも十分にパフォーマンスはでる
* 要は使いどころを間違えないこと

!slide
### 参照

* 下記の記事がunicornを丁寧に説明しています。
    * [次世代RailsサーバーUnicornを使ってみた](http://techracho.jp/?p=2075)
* 今回使ったソースの一部はgithubに上げてます
    * [hello_world_rack](https://github.com/SpringMT/hello_world_rack)
* このプレゼンもgithubに上げてあります
    * [「apache,nginx × passenger,unicornのベンチをとってみた」+ デザート](http://springmt.github.com/20120321_gaiax_lt/)
* ベンチ取るときに注意点(@kazuho)
    * [TCP通信ではデータの送信をまとめて行うべき、もうひとつの理由（＆ サーバのベンチマーク手法の話）](http://developer.cybozu.co.jp/kazuho/2009/12/tcp-064e.html)

!slide
### nginxのパッチ情報
* Memory disclosure with specially crafted backend responses
    * Severity: major
    * Not vulnerable: 1.1.17+, 1.0.14+
    * Vulnerable: 0.1.0-1.1.16

* メモリを盗み見られる脆弱性がある
* 新しいバージョン以外はほぼ対象なので、使ってるかたはパッチ当てましょう
* [nginx security advisories](http://nginx.org/en/security_advisories.html)

!slide
# 次回のネタ
* 大規模開発でのgit運用術
* fluentd
* gangliaで捗ったこと
* KVM入門
* Mysqlのあれこれ
