# みんな大好きFluentd

* 2012/06/01
* @Spring_MT

# 自己紹介

* twitter id : **@Spring_MT**

<br>
<image style="height: 200px" src="images/tiwtter_logo.jpg"/>

# 最初に

# **今日のプレゼンはSoftWare Desigh 2012 6月号 または、Fluentd Casual Talkの資料に載っている内容と重複している部分が多々ございます >_<**


# Agenda
1. Fluentdとは
1. Fluetndの構成
1. 10xlabでの構成
1. 構築手順
1. デモ
1. まとめ

# 1. Fluentdとは

# Fluentdとは
* syslogdのようなツール(リモートサーバーに転送／集約する)
* ログ収集にまつわる問題を解決し、ログを捨てずに活かすためのツール

# ログ収集に関する問題
* フォーマットが統一していない(テキストログのパースの工数がかかる)
* ログファイルの転送が重い、運用が面倒、ログロストする
    * 日毎に退避すると、リアルタイムな統計が取れない

## そこで
<image class="centered" style="height: 400px" src="images/fluentd.png"/>

# Fluentdの解決策
* JSON形式で構造化されたログメッセージ
* 高い可用性(フェイルオーバー、リトライ処理)

# その他にも
* セットアップが簡単(td-agentを使えばね！)
* プラグインによるログの入出力の拡張が容易
* 既存のシステムに手を入れなくても導入可能
* 大規模サイトでの運用実績(NHNとかcookpad)

## ベンチマーク、実績例
* 参考
    * [fluentd のベンチマークとってみたよ！](http://d.hatena.ne.jp/tagomoris/20111117/1321526727)


<div style="width:425px" id="__ss_12997699">
<iframe src="http://www.slideshare.net/slideshow/embed_code/12997699" width="425" height="355" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" allowfullscreen></iframe> <div style="padding:5px 0 12px"> View more <a href="http://www.slideshare.net/" target="_blank">presentations</a> from <a href="http://www.slideshare.net/tagomoris" target="_blank">tagomoris</a> </div> </div>

# 一応誤解のないように
* **ログを解析するのはFluentdではない！**

## 構成案
* あとで説明はしますが・・・・

<image class="centered" style="height: 500px" src="images/slide2.png"/>


# 2. Fluetndの構成

# Fluentd
* rubyの処理系を使って書かれています
* td-agentというrpmパッケージを使えば、rubyをインストールしなくても使えます

## Fluetnd概略
<image class="centered" style="height: 600px" src="images/slide1.png"/>

# Inputプラグイン
* ログの受け取りを行う
    * ソケットを待ち受けたり、ファイルから定期的にログを取得したりする
* sourceディレクティブで定義される

## Inputプラグインリスト(一部)

Name | sourceでの書き方 | Details |
----|----|----|
in_tail | tail | tailコマンドのように末尾にログが追記される度にそれをとってくる |
in_exec | exec | 外部コマンドを定期的に実行してその出力を受け取る |
in_forwar | forward | TCPソケットを待ち受けてその内容を受け取る。クライアントライブラリではこれが使われている(Logger) |

* forwardを使うには監視でUDPポートも使うので、UDPもポートを開放すること！
* [fluentd fluentd（td-agent）構築時に気をつけるポイントについて](http://d.hatena.ne.jp/oranie/20120323/1332498317)

## Input設定例(in_tail)
* nginxのアクセスログをtailする設定

~~~~
<source>
  type tail
  path /var/log/nginx/access.log
  tag nginx.cowork
  format /^(?<host>[^ ]*)\t\[(?<time>[^\]]*)\]\t"(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?"\t(?<status>[^ ]*)\t(?<body_size>[^ ]*)\t(?<response_time>[^ ]*)\t(?:"(?<agent>[^\"]*)"\t"(?<referer>[^\"]*)"\t"(?<http_x_forwarded_for>[^\"]*)"\t(?<gzip_ratio>[^ ]*))?$/
  time_format %d/%b/%Y:%H:%M:%S %z
  pos_file /var/log/td-agent/tmp/nginx.cowork.pos
</source>
~~~~

## 吐き出されるログ

~~~~
20120530T090216+0900	nginx.cowork	{
"host":"192.168.110.160",
"method":"GET",
"path":"/register/new",
"status":"304",
"body_size":"0",
"response_time":"0.010",
"agent":"Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:12.0) Gecko/20100101 Firefox/12.0",
"referer":"-",
"http_x_forwarded_for":"-",
"gzip_ratio":"-"}
~~~~


## in_tail 設定

Name | Detail |
----|----|
path | tailしたいファイルパス(権限確認). ‘,’で複数見れるっぽい |
tag | ログにつけるtag.　これをもとにoutputが判断する |
format | ログのフォーマット. 正規表現 or defaultで入っているフォーマットを指定 |
time_format | formatの中で指定した‘time’キャプチャのフォーマット |
pos_file | ここで指定したファイルに読み込んだ位置を記録する. 再起動したときその続きから再開して読み込んでくれる機能 |

* [tail](http://fluentd.org/doc/plugin.html#tail)
* pos_fileの設定はOfficial Docに載っていないのでこちらなど参照
    * [Fluent の tail input plugin に save poistion 追加されてますYO!!](http://d.hatena.ne.jp/koziy/20111115/1321372005)

## 正規表現
<image class="centered" style="width: 800px" src="images/rubular.png"/>

## Input設定例(in_forward)
* 待ち受けるportを指定する

~~~~
<source>
  type forward
  port 24224
</source>
~~~~

* bindも設定可能(defaultは0.0.0.0)
* This plugin uses MessagePack for the protocol

## num_threads

<blockquote class="twitter-tweet tw-align-center" lang="ja"><p><a href="https://twitter.com/search/%2523fluentd">#fluentd</a> で書き出しを並列化できるようにした。書き出しのスループットは出るが遅延が大きくてキューが溜まってしまうケースや、I/Oの揺らぎで書き出しが詰まってしまうようなケースで非常に有効。使い方は num_threads オプションを指定するだけ。</p>&mdash; FURUHASHI Sadayukiさん (@frsyuki) <a href="https://twitter.com/frsyuki/status/136086902276239361" data-datetime="2011-11-14T14:23:40+00:00">11月 14, 2011</a></blockquote>
<script src="//platform.twitter.com/widgets.js" charset="utf-8"></script> 


# Engine
* Inputプラグインから受け取ったログをBuffer/Outpuプラグインに受け渡す
* 特に設定は無い

# Bufferプラグイン
* Inputプラグインから受けっとたログをバッファリングする。
* ログの書き出しとログの受け取りは別スレッドで行なっているので、書き出しに時間がかかっても受け取りがブロックされることはない
* matchディレクディブで定義する = Output毎に設定可能

## Bufferプラグインリスト(一部)

Name | sourceでの書き方 | Details |
----|----|----|
buf_memory | memory | メモリに書き出す、再起動の時に失われる可能性がある(default) |
buf_file | file | ファイルに書き出す |
buf_zfile | zfile | これは使ってはだめっぽい |

* @repeatedly sanより
* http://twitter.com/repeatedly/status/207733998661812224

~~~~
BufferedOutputがデフォルトでbuf_memory
TimeSliecedOutputがデフォルトbuf_file
(これはタイムスライスによってはメモリからあふれることが普通にあるため)．
~~~~

# Outputプラグイン
* Bufferブラグインから、受けっとたログを指定の場所に書き出す
* 書き出しに失敗しても、Bufferに残っているので、再送してくれます
* matchディレクティブで定義する

## Outputプラグインリスト(一部)

Name | sourceでの書き方 | Details |
----|----|----|
out_file | file | fileへそのまま書き出し |
out_forward | forward | リモートサーバーに転送する。standby と weightで振り分け可能 |
out_exec  | exec | 外部コマンドを定期的に実行してTSVファイルに吐き出す |
out_exec_filter | exec_filter | STDIN → command → STDOUT  |
out_copy | copy | 同じログを使いまわす場合はこれを使う storeディレクティブを使う |
out_mogodb | mogodb | Mongoへ突っ込む |
out_hoop | hoop | Hadoopへ突っ込む |
out_s3 | s3| Amazon S3へ突っ込む |
out_resque | resque | Resqueにメッセージをキューイングする |

## Output設定例(out_forward)

~~~~
<match nginx.**>
  type forward
  flush_interval 5s
  retry_limit 9
  <server>
    host xsf001.10xlab.jp
    port 24224
  </server>
</match>

~~~~

## matchの書き方
#### *だと一階層しかマッチしない

* a.* は マッチする : a.b, マッチしない : a or a.b.c 

#### **だと全ての階層に(0も)マッチする

* a.** は　マッチする :  a, a.b, a.b.c 

#### {}だと、中の要素のみにマッチする
* {a, b} は マッチする : a と b, マッチしない : c

<article class='smaller'>

* **とか{}は混ぜて使える 
    *  a.{b,c}.* とか a.{b,c.**} 

</article>

## Output設定例(out_forward)

~~~~
<match nginx.**>
  type forward
  flush_interval 5s
  retry_limit 9
  <server>
    host xsf001.10xlab.jp
    port 24224
  </server>
</match>

~~~~

## out_forward 設定

Name | Detail | default |
----|----|----|
flush_interval | ログは一定量もしくは一定期間ためられて送信されるのですが、貯める時間をきめる (共通) | 60 (sec) |
retry_limit | リトライ回数 (共通) | 17 |
buffer_type | bufferする先 (共通) | memory |
retry_wait | リトライする間隔 (共通)| 1.0 |
server host | 送り先ホスト | |
server  port | 送り先のポート | |
server standby | スタンバイのサーバーの場合はyesをセット | |

## Output設定例(out_file)

~~~~
<match nginx.cowork>
  type file
  path /var/log/archive/cowork.access
  time_slice_format %Y%m%d
  time_slice_wait 1m
  time_format %Y%m%d %H:%M:%S
  compress gzip
</match>
~~~~

## out_file 設定

Name | Detail |
----|----|
path | 書き込み先ファイル(権限に気をつけて!) |
time_slice_format | ファイルのローテーションをきめる + postfixもきめる %Y%m%dだとdailyとか |
time_slice_wait| バッファをフラッシュさせる時間 |
time_format | ファイルに書き込む時間のフォーマット |
compress | ローテートする時にgzip圧縮する |

## out_file

~~~~
# ls -alh /var/log/archive/
total 20K
drwxrwxrwx   2 root     root     4.0K May 31 08:21 .
drwxr-xr-x. 18 root     root     4.0K May 29 12:28 ..
-rw-rw-rw-   1 td-agent td-agent  859 May 30 00:10 cowork.access.20120529_0.log.gz
-rw-rw-rw-   1 td-agent td-agent  378 May 31 00:10 cowork.access.20120530_0.log.gz
-rw-rw-rw-   1 td-agent td-agent  753 May 31 14:07 cowork.access.20120531.b4c14936767dad3e2
~~~~


## secondary vs standby

<blockquote class="twitter-tweet tw-align-center" data-in-reply-to="176854356577095681" lang="ja"><p>@<a href="https://twitter.com/tagomoris">tagomoris</a> secondaryが設定してある場合に17回は確かに多すぎますねぇ…。数日間はプライマリで粘るので。設定されている場合と層でない場合にデフォルト値が変わる方が良いかも…。out_forward においては standby の方が推奨です。ぜひ試してください…</p>&mdash; FURUHASHI Sadayukiさん (@frsyuki) <a href="https://twitter.com/frsyuki/status/176854915359051776" data-datetime="2012-03-06T02:21:12+00:00">3月 6, 2012</a></blockquote>
<script src="//platform.twitter.com/widgets.js" charset="utf-8"></script>


# 3. 10xlabでの構成
# Fluentdでやりたいこと
* ログのバックアップ
* アクセスログの可視化(datacounterとか)
* resqueとのつなぎ込み
* IRCログをwebから検索できる？
* Hadoop対応

## Fluetnd概略
* ちょっと復習

<image class="centered" style="height: 600px" src="images/slide1.png"/>

## 理想の構成
<image class="centered" style="height: 500px" src="images/slide2.png"/>

# 構成要素
* **Deliver** : LB的な役割 (受けて流すだけ)
* **Worker**  : 受けっとたログを解析、処理する
* **Watcher** : 監視用


## 今回なんとかしたい構成
<image class="centered" style="height: 500px" src="images/slide3.png"/>
（　´・ω・｀）＜ ショボいな 

# 4. 構築手順

# 4-1. Fluentd on the Web Server

# Fluentd on the Web Server
* 今回10xlabはrailsを使っているので、rubyの処理系はすでに入っていることをが前提なので、Web Serverにはgemを使ってインストールします。

## 使用するruby
* 1.9.3p125以上がstrictly recommendedです！
* rubyをインストールする場合は、rvm rbenvなどのRubyバージョン管理ツールを使う捗ります
    * 個人的にはrbenvを使ってかつ、自前ビルドがオススメです。
    * [rvmやめてrbenvにしました](http://spring-mt.tumblr.com/post/18486237491/rvm-rbenv)

## gemでインストール

~~~~
$ gem install fluentd
Successfully installed msgpack-0.4.7
Successfully installed yajl-ruby-1.1.0
Successfully installed iobuffer-1.1.2
Successfully installed cool.io-1.1.0
Successfully installed http_parser.rb-0.5.3
Successfully installed fluentd-0.10.22
6 gems installed
$ source .bash_profile 
$ fluentd --setup ./fluent
Installed ./fluent/fluent.conf.
~~~~

## Web Server上でのFluentdへログを投げる方法
* アプリ側でログをはいて、Fluentdでtailする
    * 日付別にログを履いているとsym link貼ってdailyでrotateが必要
* FluentdLoggerを使う(forwardと同じでtcp経由でFluentdに投げる)


# 4-2. Deliver
# インストール
* おそらくFedora10以降だとyumでは入りません(Official Docの手順)
* 少なくともFedora16ではだめでした
* インストールにはrpmが必要なので、rpm作成から

# rpm作成
* ここに書いてあります！
* [fedora16-x86-64-fluentd](http://spring-mt.tumblr.com/post/23988588379/fedora16-x86-64-fluentd)

* 必要であればrpm作成しますよー

## インストール
* rpm -ivh でインストールしてもらえれば良いのですが、td-libyamがないと入らないのでそれだけyumで入れます
* forwardして受け取るので、待受ポート(tcpとudp)を開けて、iptablesを再起動しておいてくださいね！

~~~~
# vim /etc/yum.repos.d/td.repo
[treasuredata]
name=TreasureData
baseurl=http://packages.treasure-data.com/redhat/$basearch
gpgcheck=0

# yum install td-libyaml
# rpm -ivh td-agent-1.1.6-0.fc16.x86_64.rpm 
# /usr/lib64/fluent/ruby/bin/fluent-gem install fluentd
# /etc/init.d/td-agent start
~~~~

## Warning of "installation is missing psych"

<blockquote class="twitter-tweet tw-align-center" lang="ja"><p>とりあえず psych から libyaml 依存性を取り除いて欲しいですね（キリッ</p>&mdash; Kazuki Ohtaさん (@kzk_mover) <a href="https://twitter.com/kzk_mover/status/194621144446418945" data-datetime="2012-04-24T02:57:51+00:00">4月 24, 2012</a></blockquote>
<script src="//platform.twitter.com/widgets.js" charset="utf-8"></script>

* [Ruby 1.9.3で "missing psych"](http://maeda.farend.ne.jp/blog/2012/03/10/ruby-missing-pysh/)
* [Ruby1.9.2で日本語を含むYAMLを出力する時、バイナリ文字列化されないようにする](http://keijinsonyaban.blogspot.jp/2010/10/ruby192yaml.html)

# 4-3. Worker
* ここはそれぞれ
* pluginはいれないといけない
* mongoの例

~~~~ 
# /usr/lib64/fluent/ruby/bin/fluent-gem install fluent-plugin-mongo

~~~~


## Reference

<br>

<iframe src="http://rcm-jp.amazon.co.jp/e/cm?lt1=_blank&bc1=000000&IS2=1&bg1=FFFFFF&fc1=000000&lc1=0000FF&t=blueskyblue00-22&o=9&p=8&l=as4&m=amazon&f=ifr&ref=ss_til&asins=B007Y725LE" style="width:120px;height:240px;" scrolling="no" marginwidth="0" marginheight="0" frameborder="0"></iframe>

* なにはともあれ、買って損はないです！

## Reference 2
* [Fluentd official](http://fluentd.org/)
* [イベントログ収集ツール fluent リリース！](http://d.hatena.ne.jp/viver/20110929/p1)

* [fluentd のベンチマークとってみたよ！](http://d.hatena.ne.jp/tagomoris/20111117/132152672)
* [Perl から Fluentd にログ出力 - Fluent::Logger リリース](http://d.hatena.ne.jp/sfujiwara/20120131/1327973658)
* [Subsonic+Nginxのアクセスログをfluentdを利用してMongoDBに入れてみた](http://blog.glidenote.com/blog/2012/05/21/fluentd-nginx-mongodb/)

* [Fluentd Casual Talks 開催してきた＆しゃべってきた](http://d.hatena.ne.jp/tagomoris/20120521/1337569528)
* [Fluentd Casual Talksに参加してきました](http://6pongi.wordpress.com/2012/05/31/fluentcasualtalks/)
* [Fluentd meetup in Japanに参加してきました。](http://tech.hatenablog.com/entry/2012/02/05/000100)

## slide
* [Distributed Stream Processing on Fluentd / #fluentd](http://www.slideshare.net/tagomoris/distributed-stream-processing-on-fluentd-fluentd)
* [fluentd を利用した大規模ウェブサービスのロギング](http://www.slideshare.net/hotchpotch/20120204fluent-logging) 
* [fluentd Casual Talks by oranie](http://www.slideshare.net/oranie/fluentd-casual-12981506)
* [Plugins by tagomoris #fluentdcasual](http://www.slideshare.net/tagomoris/plugins-by-tagomoris-fluentdcasual)
* [Introduction of 'fluentd'](http://www.slideshare.net/naverjapan/introduction-of-fluent)


## github
* [fluent / fluentd](https://github.com/fluent/fluentd/)
* [fluent-logger-ruby](https://github.com/fluent/fluent-logger-ruby)


## Tool
* [a Ruby regular expression editor](http://www.rubular.com/)


